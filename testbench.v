`timescale 1ns/10ps

`ifdef syn
`include "tsmc18.v"
`include "np_sync.v"
`else
`include "np.v"
`endif
//---------------------------------------------------------------------------------------------------------
module test;
reg reset,clk;
`timescale 1ns/10ps
module np;
parameter CYCLE = 10;//clock time
parameter WIDTH = 32;//32 bits instruction
parameter ADDRSIZE = 12;//size of mem(# of data)
parameter MEMSIZE = (1<<ADDRSIZE) ;//(2^12)
parameter MAXREGS = 16;//Maximum # of registers
parameter SBITS = 5;//Status register bits
//Declare Registers ang Memory
reg [WIDTH-1:0]MEM[0:MEMSIZE-1],// Memory
               RFILE[0:MAXREGS-1],//Register file
               ir,// Instruction register
               src1,src2;// Alu operation registers
reg[WIDTH:0]result;// ALU result register
reg[SBITS-1:0]psr;// Processer counter for condition check
reg[ADDRSIZE-1:0]pc;// Program counter
reg dir;// Rotate direction
reg reset;// System Reset
integer i;

// General definitions
`define TRUE 1
`define FALSE 0

// Define Instruction fields

`define OPCODE  ir[31:28]
`define SRC     ir[23:12]
`define DST     ir[11:0]
`define SRCTYPE ir[27]// source type 1 => imm 、0 => reg or mem
`define DSTTYPE ir[26]// destination type 1 => imm 、0 => reg or mem
`define CCODE   ir[27:24]//condition code for branch
`define SRCNT   ir[23:12]//Shift/rotate count -= left, +=right
// Operand Types
`define REGTYPE 0
`define IMMTYPE 1
// Define opcode for each instruction

`define NOP 4'b0000
`define BRA 4'b0001
`define LD  4'b0010
`define STR 4'b0011
`define ADD 4'b0100
`define MUL 4'b0101
`define CMP 4'b0110
`define SHF 4'b0111
`define ROT 4'b1000
`define SUB 4'b1001    // SUB R0 R1  <= R0 = R0 - R1
`define OR 4'b1010    // OR R0 R1  <= R0 = R0 or R1
`define HLT 4'b1011

// Define Condition code fields
`define CARRY  psr[0]
`define EVEN   psr[1]
`define PARITY psr[2]
`define ZERO   psr[3]
`define NEG    psr[4]

// Define Condition Code
`define CCC 1 // Result has carry
`define CCE 2 // Result is  even
`define CCP 3 // Result is  odd parity
`define CCZ 4 // Result is  zero
`define CCN 5 // Result is  negative
`define CCA 0 // Always

`define RIGHT 0// Rotate / Shift Right
`define LEFT  1// Rotate / Shift Left

//---------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------
`ifdef syn
initial $sdf_annotate ("np_sync.sdf", tff);
`endif
//---------------------------------------------------------------------------------------------------------
//begin the clk
initial
begin
  clk = 0;
  reset = 1;
  #CYCLE reset = 0;
end

always #(CYCLE/2) clk = ~clk;
//---------------------------------------------------------------------------------------------------------

initial begin:prog_load
    $readmemb("risc.prog",MEM);
    $monitor("%d %d %b %b", $time, pc, RFILE[0], RFILE[1]);
    apply_reset;
end
//---------------------------------------------------------------------------------------------------------

`ifdef syn
initial begin
	$dumpfile("np_sync.vcd");
	$dumpvars;
end
`else
initial begin
	$dumpfile("np.vcd");
	$dumpvars;
end
`endif

endmodule 
