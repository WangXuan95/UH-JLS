`timescale 1 ns/1 ns

module shift_buffer #(
    parameter  WLEVEL = 12,
    parameter  DWIDTH = 8
) (
    input                rst,
    input                clk,
    
    input  [WLEVEL-1:0]  length,  // length = 0 ~ (1<<WLEVEL-1)
    
    input                ivalid,
    input  [DWIDTH-1:0]  idata,

    output [DWIDTH-1:0]  odata
);

localparam MAXLEN = 1<<WLEVEL;

reg               rvalid = 1'b0;
wire [DWIDTH-1:0] rdata;
reg  [DWIDTH-1:0] ldata = '0;
reg  [WLEVEL-1:0] ptr = '0;

always @ (posedge clk)
    if(rst)
        ptr <= '0;
    else begin
        if(ivalid) begin
            if(ptr<length)
                ptr <= ptr + { {(WLEVEL-1){1'b0}}, 1'b1 };
            else
                ptr <= '0;
        end
    end

always @ (posedge clk)
    if(rst)
        rvalid <= 1'b0;
    else
        rvalid <= ivalid;

always @ (posedge clk)
    if(rvalid)
        ldata <= rdata;
    
assign odata = rvalid ? rdata : ldata;

RAM #(
    .SIZE     ( MAXLEN      ),
    .WIDTH    ( DWIDTH      )
) ram_shift (
    .clk      ( clk         ),
    .wen      ( ivalid      ),
    .waddr    ( ptr         ),
    .wdata    ( idata       ),
    .raddr    ( ptr         ),
    .rdata    ( rdata       )
);

endmodule







module RAM #(
    parameter  SIZE     = 1024,
    parameter  WIDTH    = 32
)(
    clk,
    wen,
    waddr,
    wdata,
    raddr,
    rdata
);

function automatic integer clogb2(input integer val);
    integer valtmp;
    valtmp = val;
    for(clogb2=0; valtmp>0; clogb2=clogb2+1) valtmp = valtmp>>1;
endfunction

input                       clk;
input                       wen;
input  [clogb2(SIZE-1)-1:0] waddr;
input  [WIDTH-1:0]          wdata;
input  [clogb2(SIZE-1)-1:0] raddr;
output [WIDTH-1:0]          rdata;

wire                        clk;
wire                        wen;
wire   [clogb2(SIZE-1)-1:0] waddr;
wire   [WIDTH-1:0]          wdata;
wire   [clogb2(SIZE-1)-1:0] raddr;
reg    [WIDTH-1:0]          rdata;

reg [WIDTH-1:0] mem [SIZE];

always @ (posedge clk)
    if(wen)
        mem[waddr] <= wdata;

initial rdata = '0;
always @ (posedge clk)
    rdata <= mem[raddr];

endmodule

