`timescale 1 ns/1 ns

module source(
    input  wire        rst,
    input  wire        clk,
    
    input  wire [ 9:0] width,
    input  wire [15:0] height,
    
    input  wire        ena,
    
    input  wire [ 7:0] i_b  [1:8 ],
    input  wire [ 7:0] i_x  [1:8 ],
    
    output reg         o_sl,
    output reg         o_sp,
    output reg         o_ep,
    output reg         o_vl,
    output reg  [ 7:0] o_b  [1:10],
    output reg  [ 7:0] o_x  [1:8 ]
);

reg  [15:0] vpos;
reg  [ 9:0] hpos;

reg         a_sl;
reg         a_sp;
reg         a_ep;
reg         a_vl;
reg  [ 7:0] a_b [1:8];
reg  [ 7:0] a_x [1:8];

always @ (posedge clk)
    if(ena) begin
        if( hpos < width ) begin
            hpos <= hpos + 10'd1;
        end else begin
            vpos <= vpos + 16'd1;
            hpos <= 10'd0;
        end
        a_sl <= (vpos=='0);
        a_sp <= (vpos<height) && (hpos=='0);
        a_ep <= (vpos<height) && (hpos==width);
        a_vl <= (vpos<height);
        if(vpos=='0)
            a_b <= '{8{8'd0}};
        else
            a_b <= i_b;
        a_x <= i_x;
    end else if(rst) begin
        vpos <= '0;
        hpos <= '0;
        a_sl <= '0;
        a_sp <= '0;
        a_ep <= '0;
        a_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        o_sl <= a_sl;
        o_sp <= a_sp;
        o_ep <= a_ep;
        o_vl <= a_vl;
        for(int i=1;i<=8;i++) o_b[i] <= a_b[i];
        o_b[9]  <= a_sl ?                '0   : ( a_ep ?  a_b[8] : i_b[1] );
        o_b[10] <= a_sl ? ( a_ep ? 8'd1: '0 ) : ( a_ep ? ~a_b[8] : i_b[2] );
        o_x <= a_x;
    end else if(rst) begin
        o_sl <= '0;
        o_sp <= '0;
        o_ep <= '0;
        o_vl <= '0;
    end

endmodule
