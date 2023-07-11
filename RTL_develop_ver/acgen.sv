`timescale 1 ns/1 ns

module acgen(
    input  wire        rst,
    input  wire        clk,
    input  wire        ena,
    input  wire        i_sl,
    input  wire        i_sp,
    input  wire        i_vl,
    input  wire [ 1:0] i_st [1:8],
    input  wire [ 7:0] i_b  [1:9],
    input  wire [ 7:0] i_x  [1:8],
    output reg         o_sp,
    output reg         o_vl,
    output reg  [ 1:0] o_st [1:8],
    output reg  [ 7:0] o_b  [0:9],
    output reg  [ 7:0] o_x  [0:8]
);

reg  [ 7:0] startpixel;

always @ (posedge clk)
    if(ena) begin
        startpixel <= i_sp ? i_b[1] : startpixel;
        o_sp <= i_sp;
        o_vl <= i_vl;
        o_st <= i_st;
        o_b[0] <= i_sl ? '0 : ( i_sp ? startpixel : o_b[8] );
        o_x[0] <= i_sp ? i_b[1] : o_x[8];
        for(int i=1;i<=9;i++) o_b[i] <= i_b[i];
        for(int i=1;i<=8;i++) o_x[i] <= i_x[i];
    end else if(rst) begin
        startpixel <= '0;
        o_sp <= '0;
        o_vl <= '0;
    end

endmodule
