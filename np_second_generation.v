/*==================================
* Model of RISC without pipeline.
* Three main task => fetch,execute,write
*/
`timescale 1ns/10ps
module np(clk,reset,wr,address,dataIn,dataOut,halt);

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

reg[1:0]state,next_state;//define the state of the cpu
integer i;
//define input and output
input clk,reset;
input [WIDTH-1:0]dataIn;
output [ADDRSIZE-1:0]address;
output reg [WIDTH-1:0]dataOut;
output reg wr,halt;
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

parameter FET = 2'b00,EXE = 2'b01,WB = 2'b10;

// Function for ALU operands and result
function[WIDTH-1:0] getsrc;
input [WIDTH-1:0]in;
begin 
    if(`SRCTYPE == `REGTYPE) 
        getsrc = RFILE[`SRC];
    else 
        getsrc = `SRC;//immediate type
end
endfunction

function [WIDTH-1:0]getdst;
input [WIDTH-1:0]in;
begin
    if(`DSTTYPE == `REGTYPE)
        getdst = RFILE[`DST];
    else ;
end
endfunction

// Function / task for condition code
function checkcond;//Return 1 if conditon code is set
input[4:0]ccode;
begin
    case (ccode)
        `CCC:checkcond = `CARRY;
        `CCE:checkcond = `EVEN; 
        `CCP:checkcond = `PARITY; 
        `CCZ:checkcond = `ZERO; 
        `CCN:checkcond = `NEG; 
        `CCA:checkcond = 1; 
    endcase
end
endfunction

task clearcondcode;// Reset condition code in PSR
begin
    psr = 0;
end
endtask

task setcondcode;// Compute the condition codes and set PSR
input [WIDTH:0]res;//ALU result register
begin
    `CARRY = res[WIDTH];
    `EVEN = ~res[0];//check even
    `PARITY = ^res;//even # of 1 => 0, odd # of 1 => 1
    `ZERO = ~(|res);
    `NEG = res[WIDTH-1];
end
endtask

// Main Tasks - fetch execute write_result
task fetch;
begin
    ir = MEM[pc];
    pc = pc + 1;
end
endtask

task execute;
begin
    case (`OPCODE)
    `NOP:$display("NOP");
    `BRA: begin
        if(checkcond(`CCODE)==1)
            pc = `DST; 
    end
    `LD:begin
        clearcondcode;
        if(`SRCTYPE == `IMMTYPE)
            RFILE[`DST] = `SRC;
        else
            RFILE[`DST] = MEM[`SRC];
        setcondcode({1'b0,RFILE[`DST]});
    end
    `STR: begin
        clearcondcode;
        if(`SRCTYPE == `IMMTYPE)
            MEM[`DST] = `SRC;
        else
            MEM[`DST] = RFILE[`SRC];
        if(`SRCTYPE == `IMMTYPE)
            setcondcode({21'b0,`SRC});
        else
            setcondcode({1'b0,RFILE[`SRC]});
    end
    `ADD: begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src1 + src2;
        setcondcode(result);
    end
    `MUL: begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src1 * src2;
        setcondcode(result);
    end
    `CMP: begin // complement
        clearcondcode;
        src1 = getsrc(ir);
        result = ~src1;
        setcondcode(result);
    end
    `SHF:begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        i = (src1[ADDRSIZE-1]>=0)?src1:-src1[ADDRSIZE-1:0];
        result = (i>0)?(src2>>i):(src2<<-i);
        setcondcode(result);
    end
    `ROT:begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);  
        dir = src1[ADDRSIZE-1] >=0 ?`RIGHT:`LEFT;
        i = (src1[ADDRSIZE-1]>=0)?src1:-src1[ADDRSIZE-1:0];
        while(i > 0)begin
            if(dir==`RIGHT)begin
                result = src2 >> 1;
                result[WIDTH-1] = src2[0];
            end
            else begin
                result = src2 << 1;
                result[0] = src2[WIDTH-1]; 
            end
            i = i - 1;
            src2 = result;
        end
    end
    `SUB: begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src2 - src1;
        setcondcode(result);
      end
     `OR: begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src2 | src1;
        setcondcode(result);
      end
    `HLT:begin
        $display("Halt...");
        $finish;
    end
    default:;
    endcase
end
endtask

//Write the result in register file or memory
task write_result;
begin    
    if((`OPCODE >= `ADD) && (`OPCODE < `HLT))begin
        if(`DSTTYPE == `REGTYPE)begin
            RFILE[`DST] = result;
        end
        else begin
            MEM[`DST] = result;
        end
    end
end
endtask


always @(posedge clk) begin
    if(reset) begin
        state <= FET;
        pc <= 0;
    end
    else begin
        state <= next_state;
        pc <= pc;
    end
end

always @(state) begin
	case(state)	
	FET:next_state = EXE;
	EXE:next_state = WB;
	WB:next_state = FET;
	default:next_state = FET;	
	endcase	
end

endmodule
