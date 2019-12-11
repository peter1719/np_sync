/*==================================
* Model of RISC without pipeline.
* Three main task => fetch,execute,write
*/
// `timescale 1ns/10ps
module np(clk,reset,in_wr,wr,in_address,in_dataIn,in_dataOut,address,dataIn,dataOut,halt);

parameter WIDTH = 32;//32 bits instruction
parameter ADDRSIZE = 12;//size of mem(# of data)
parameter MEMSIZE = (1<<ADDRSIZE) ;//(2^12)
parameter MAXREGS = 16;//Maximum # of registers
parameter SBITS = 5;//Status register bits
//Declare Registers ang Memory
reg [WIDTH-1:0]RFILE[0:MAXREGS-1],//Register file
               ir,// Instruction register
               src1,src2;// Alu operation registers
reg [WIDTH-1:0]RFILE_r[0:MAXREGS-1];//Register file
reg[WIDTH:0]result;// ALU result register
reg[SBITS-1:0]psr;// Processer counter for condition check
reg[ADDRSIZE-1:0]pc;// Program counter
reg[WIDTH*2-1:0] rot;// Rotate 
reg[ADDRSIZE-1:0]pc_r;
reg [WIDTH-1:0]ir_r;// Instruction register
reg[WIDTH:0]result_r;// ALU result register
reg[SBITS-1:0]psr_r;// Processer counter for condition check
reg[1:0]state,next_state;//define the state of the cpu

integer i;
//define input and output
input clk,reset;
input [WIDTH-1:0]in_dataIn;
input [WIDTH-1:0]dataIn;
output reg [ADDRSIZE-1:0]in_address;
output reg [ADDRSIZE-1:0]address;
output reg [WIDTH-1:0]in_dataOut;
output reg [WIDTH-1:0]dataOut;
output reg wr,in_wr,halt;
//wr : 1 for write 0 for read
// General definitions
`define TRUE 1
`define FALSE 0

// Define Instruction fields

`define OPCODE  ir[31:28]
`define SRC     ir[23:12]
`define DST     ir[11:0]
`define SRCTYPE ir[27]// source type 1 => imm 、0 => reg or mem
`define DSTTYPE ir[26]// destin_ation type 1 => imm 、0 => reg or mem
`define CCODE   ir[27:24]//condition code for branch
`define SRCNT   ir[23:12]//Shift/rotate count -= left, +=right
// Operand Types
`define REGTYPE 0
`define IMMTYPE 1
// Define opcode for each instruction

`define NOP 4'b0000
`define BRA 4'b0001
`define STR 4'b0010
`define LD  4'b0011
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

// `define RIGHT 0// Rotate / Shift Right
// `define LEFT  1// Rotate / Shift Left

parameter FET = 2'b00,EXE = 2'b01,WB = 2'b10,RESET = 2'b11;

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
        default:checkcond = 0;
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
    in_wr = 0;
    ir = in_dataIn;
end
endtask

task execute;
begin
    case (`OPCODE)
    `NOP: $display("NOP");   
    `BRA: begin
        if(checkcond(`CCODE)==1)begin
            pc = `DST; 
            $display("BRA");
        end
    end
    `LD: begin
        clearcondcode;
        $display("LD");
        if(`SRCTYPE == `IMMTYPE) begin
            result = `SRC;
        end
        else begin
            wr = 0;
            address = `SRC;
        end
        //setcondcode(result);
    end
    `STR: begin
        $display("STR");   
        clearcondcode;
        wr = 1;
        address = `DST;
        if(`SRCTYPE == `IMMTYPE) 
            result = `SRC;
        else 
            result = RFILE[`SRC];
        //setcondcode(result);
    end
    `ADD: begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src1 + src2;
        $display("ADD");     
        //setcondcode(result);
    end
    `MUL: begin
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src1 * src2;
        //setcondcode(result);
        $display("MUL"); 
    end
    `CMP: begin // complement
        clearcondcode;
        src1 = getsrc(ir);
        result = ~src1;
        //setcondcode(result);
        $display("CMP");     
    end
    `SHF:begin // test it
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        i = src1;
        result = (i>0)?(src2>>i):(src2<<-i);
        $display("SHF %d",i);        
        //setcondcode(result);
    end
    `ROT:begin // rebuild it
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);  
        i = src1;
        if(i>0) begin
            rot = ({src2,src2}<<-i);
            result = rot[31:0];
        end
        else begin
            rot = ({src2,src2}<<-i);
            result = rot[63:32];
        end
        $display("ROT %d",i);        
    end
    `SUB: begin
        // $display("SUB");  
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src2 - src1;
        $display("SUB"); 
        //setcondcode(result);
      end
     `OR: begin
        $display("OR");   
        clearcondcode;
        src1 = getsrc(ir);
        src2 = getdst(ir);
        result = src2 | src1;
        //setcondcode(result);
      end
    `HLT: begin
        halt = 1;        
        // $display("Halt...");
        // $finish;
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
            $display("error!!");
        end
        setcondcode(result);
    end
    else if((`OPCODE == `LD))begin
        if(`SRCTYPE != `IMMTYPE) begin // load from datamemory
            wr = 0;
            address = `SRC;
            result = dataIn;
        end
        if(`DSTTYPE == `REGTYPE)begin
            RFILE[`DST] = result;
        end
        else begin
            $display("error!!");
        end
        setcondcode(result);
    end
    else if((`OPCODE == `STR))begin // store the value to memory
        wr = 1;
        address = `DST;
        dataOut = result[31:0];
        setcondcode(result);
    end

    if(!(`OPCODE == `BRA))begin 
        pc = pc_r + 1;//next instruction ,preassign instruction address       
    end
end
endtask

always@(*)begin
    $display("%d %d %b %h", $time, pc, RFILE[0], RFILE[1]);
end

always @(posedge clk) begin
    if(reset) begin
        state <= RESET;
        pc_r <= 0;
        result_r <= 0;
        psr_r <= 0;
        //
        RFILE_r[0] <= 0;
        RFILE_r[1] <= 0;
        RFILE_r[2] <= 0;
        RFILE_r[3] <= 0;
        RFILE_r[4] <= 0;
        RFILE_r[5] <= 0;
        RFILE_r[6] <= 0;
        RFILE_r[7] <= 0;
        RFILE_r[8] <= 0;
        RFILE_r[9] <= 0;
        RFILE_r[10] <= 0;
        RFILE_r[11] <= 0;
        RFILE_r[12] <= 0;
        RFILE_r[13] <= 0;
        RFILE_r[14] <= 0;
        RFILE_r[15] <= 0;        
    end
    else begin
        pc_r <= pc;
        result_r <= result;
        state <= next_state;
        psr_r <= psr;
        //
        RFILE_r[0] <= RFILE[0];
        RFILE_r[1] <= RFILE[1];
        RFILE_r[2] <= RFILE[2];
        RFILE_r[3] <= RFILE[3];
        RFILE_r[4] <= RFILE[4];
        RFILE_r[5] <= RFILE[5];
        RFILE_r[6] <= RFILE[6];
        RFILE_r[7] <= RFILE[7];
        RFILE_r[8] <= RFILE[8];
        RFILE_r[9] <= RFILE[9];
        RFILE_r[10] <= RFILE[10];
        RFILE_r[11] <= RFILE[11];
        RFILE_r[12] <= RFILE[12];
        RFILE_r[13] <= RFILE[13];
        RFILE_r[14] <= RFILE[14];
        RFILE_r[15] <= RFILE[15];
    end
end

always @(state) begin
    pc = pc_r;
    halt = 0;
    in_wr = 0;
    wr = 0;
    address = 0;
    in_address = pc;
    ir = in_dataIn;
    dataOut = 0;
    src1 = 0;
    src2 = 0;
    result = result_r;
    psr = psr_r;
    rot = 0;
    
    RFILE[0] = RFILE_r[0];
    RFILE[1] = RFILE_r[1];
    RFILE[2] = RFILE_r[2];
    RFILE[3] = RFILE_r[3];
    RFILE[4] = RFILE_r[4];
    RFILE[5] = RFILE_r[5];
    RFILE[6] = RFILE_r[6];
    RFILE[7] = RFILE_r[7];
    RFILE[8] = RFILE_r[8];
    RFILE[9] = RFILE_r[9];
    RFILE[10] = RFILE_r[10];
    RFILE[11] = RFILE_r[11];
    RFILE[12] = RFILE_r[12];
    RFILE[13] = RFILE_r[13];
    RFILE[14] = RFILE_r[14];
    RFILE[15] = RFILE_r[15];
    /*
    reg [WIDTH-1:0]RFILE[0:MAXREGS-1],//Register file
    */
	case(state)	
	FET:begin
        fetch;
        next_state = EXE;
    end
	EXE:begin
        execute;
        next_state = WB;
    end
	WB:begin
        write_result;
        next_state = FET;
    end
	default:begin // for reset
        next_state = FET;
        pc = 0;	
    end
	endcase	
end

endmodule

