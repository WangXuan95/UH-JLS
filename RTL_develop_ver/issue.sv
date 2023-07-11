`timescale 1 ns/1 ns

module issue(
    input  wire        rst,
    input  wire        clk,
    output wire        stall_n,
    input  wire        i_vl,
    input  wire [ 7:0] i_x  [1:8],
    input  wire [ 7:0] i_px [1:8],
    input  wire        i_s  [1:8],
    input  wire [ 4:0] i_qh [1:8],
    input  wire [ 3:0] i_ql [1:8],
    input  wire [ 2:0] i_qcnt [1:8],
    input  wire [ 2:0] i_qcnt_max,
    input  wire [13:0] i_rl [1:8],
    output reg         o_et,
    output reg  [ 7:0] o_x  [1:8],
    output reg  [ 7:0] o_px [1:8],
    output reg         o_s  [1:8],
    output reg  [ 4:0] o_qh [1:8],
    output reg  [ 3:0] o_ql [1:8],
    output reg  [13:0] o_rl
);

reg  [ 2:0] a_cnt;
reg         a_vl;
reg  [ 7:0] a_x  [1:8];
reg  [ 7:0] a_px [1:8];
reg         a_s  [1:8];
reg  [ 4:0] a_qh [1:8];
reg  [ 3:0] a_ql [1:8];
reg  [ 2:0] a_qcnt [1:8];
reg  [13:0] a_rl [1:8];

reg  [13:0] b_rl [1:8];

assign o_rl = b_rl[1] | b_rl[2] | b_rl[3] | b_rl[4] | b_rl[5] | b_rl[6] | b_rl[7] | b_rl[8];

assign stall_n = a_cnt==3'd0;

always @ (posedge clk)
    if(rst) begin
        a_cnt<= '0;
        a_vl <= '0;
    end else if(stall_n) begin
        a_vl <= i_vl;
        if(i_vl) begin
            a_cnt<= i_qcnt_max;
            a_x  <= i_x;
            a_px <= i_px;
            a_s  <= i_s;
            a_qh <= i_qh;
            a_ql <= i_ql;
            a_qcnt <= i_qcnt;
            a_rl <= i_rl;
        end
    end else begin
        a_cnt <= a_cnt - 3'd1;
    end

always @ (posedge clk) begin
    o_et <= rst ? 1'b0 : (a_vl & stall_n);
    o_x  <= a_x;
    o_px <= a_px;
    o_s  <= a_s;
    o_qh <= a_qh;
    for(int i=1; i<=8; i++) begin
        o_ql[i] <= (~rst && a_vl && a_qcnt[i]==a_cnt && a_ql[i]!=4'hf) ? a_ql[i] :  4'hf;
        b_rl[i] <= (        a_vl && a_qcnt[i]==a_cnt && a_ql[i]==4'hd) ? a_rl[i] : 14'h0;
    end
end

endmodule
