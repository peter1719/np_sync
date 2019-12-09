module inMemory(dataOut,dataIn,address,reset,wr,clk);
parameter WIDTH = 32;//32 bits instruction
parameter ADDRSIZE = 12;//size of mem(# of data)
parameter MEMSIZE = (1<<ADDRSIZE);//(2^12)

input clk,reset,wr;
input [WIDTH-1:0]dataIn;
input [ADDRSIZE-1:0]address;
output reg [WIDTH-1:0]dataOut;
reg [WIDTH-1:0]MEM[0:MEMSIZE-1];

always @(posedge clk) begin
    if(reset) begin
        $readmemb("risc.prog", MEM);
    end
    else if(wr) begin
        MEM[address] = dataIn;
    end
    else begin
        dataOut = MEM[address] ;
    end    
end
endmodule