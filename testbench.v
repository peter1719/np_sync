`timescale 1ns/10ps
`ifdef syn
`include "tsmc18.v"
`include "np_sync.v"
`else
`include "np_second_generation.v"
`include "memory.v"
`include "inMemory.v"

`endif
//---------------------------------------------------------------------------------------------------------
module test;
parameter WIDTH = 32;//32 bits instruction
parameter ADDRSIZE = 12;//size of mem(# of data)
parameter MEMSIZE = (1<<ADDRSIZE) ;//(2^12)
parameter CYCLE = 10;//clock time
reg clk,reset;
wire[WIDTH-1:0]CPU_dataIn;
wire [WIDTH-1:0]CPU_dataOut;
wire[ADDRSIZE-1:0]address;
wire[WIDTH-1:0]CPU_in_dataIn;
wire [WIDTH-1:0]CPU_in_dataOut;
wire[ADDRSIZE-1:0]in_address;
wire in_wr,wr,halt;
np mnp(.clk(clk),.reset(reset),.address(address),.dataIn(CPU_dataIn),.dataOut(CPU_dataOut),.wr(wr),
.in_wr(in_wr),.in_address(in_address),.in_dataIn(CPU_in_dataIn),.in_dataOut(CPU_in_dataOut),.halt(halt));

memory mem(.dataOut(CPU_dataIn),.dataIn(CPU_dataOut),.address(address),.reset(reset),.wr(wr),.clk(clk));
inMemory mem2(.dataOut(CPU_in_dataIn),.dataIn(CPU_in_dataOut),.address(in_address),.reset(reset),.wr(in_wr),.clk(clk));

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
  #(3*CYCLE) reset = 0;
end

always #(CYCLE/2) clk = ~clk;
//---------------------------------------------------------------------------------------------------------
always @(halt) begin
  if(halt)begin
    $display("halt");
    $finish;
  end
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
