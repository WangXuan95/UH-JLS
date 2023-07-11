`timescale 1 ns/1 ns

// 2 stage pipeline
module sort(
    input  wire        rst,
    input  wire        clk,
    input  wire        i_et,
    input  wire [ 7:0] i_x  [1:8],
    input  wire [ 7:0] i_px [1:8],
    input  wire        i_s  [1:8],
    input  wire [ 4:0] i_qh [1:8],
    input  wire [ 3:0] i_ql [1:8],
    input  wire [13:0] i_rl,
    output reg         o_et,
    output reg         o_vl [0:13],
    output reg  [ 7:0] o_x  [0:13],
    output reg  [ 7:0] o_px [0:13],
    output reg         o_s  [0:13],
    output reg  [ 4:0] o_qh [0:13],
    output reg  [ 3:0] o_ql [1:8],
    output reg  [13:0] o_rl
);

reg         a_et;
reg         a_vl [0:13];
reg  [ 2:0] a_adr[0:13];
reg  [ 7:0] a_x  [0:7];
reg  [ 7:0] a_px [0:7];
reg         a_s  [0:7];
reg  [ 4:0] a_qh [0:7];
reg  [ 3:0] a_ql [1:8];
reg  [13:0] a_rl;

always @ (posedge clk) begin
    a_et <= rst ? 1'b0 : i_et;
    for(logic [3:0] jj=4'd0; jj<=4'd13; jj++) begin
        a_vl[jj] <= '0;
        a_adr[jj] <= '0;
        for(logic [3:0] ii=4'd0; ii<=4'd7; ii++) begin
            if(i_ql[ii+4'd1]==jj) begin
                a_vl[jj] <= ~rst;
                a_adr[jj] <= ii[2:0];
            end
        end
    end
    for(int ii=0; ii<8; ii++) begin
        a_x[ii] <= i_x[ii+1];
        a_px[ii] <= i_px[ii+1];
        a_s[ii] <= i_s[ii+1];
        a_qh[ii] <= i_qh[ii+1];
    end
    a_rl <= i_rl;
    if(rst)
        a_ql <= '{8{4'hf}};
    else
        a_ql <= i_ql;
end

always @ (posedge clk) begin
    o_et <= rst ? 1'b0 : a_et;
    if(rst) begin
        o_vl <= '{14{1'b0}};
        o_ql <= '{ 8{4'hf}};
    end else begin
        o_vl <= a_vl;
        o_ql <= a_ql;
    end
    for(logic [3:0] jj=4'd0; jj<=4'd13; jj++) begin
        o_x[jj] <= a_x[a_adr[jj]];
        o_px[jj] <= a_px[a_adr[jj]];
        o_s[jj] <= a_s[a_adr[jj]];
        o_qh[jj] <= a_qh[a_adr[jj]];
    end
    o_rl <= a_rl;
end

endmodule
