`timescale 1 ns/1 ns

// 3 stage pipeline
module preprocess(
    input  wire        rst,
    input  wire        clk,
    input  wire        ena,
    input  wire        i_sp,
    input  wire        i_vl,
    input  wire [ 7:0] i_b  [0:8],
    input  wire [ 7:0] i_x  [0:8],
    input  wire        i_s  [1:8],
    input  wire [ 4:0] i_qh [1:8],
    input  wire [ 3:0] i_ql [1:8],
    input  wire [ 2:0] i_qcnt [1:8],
    output reg         o_vl,
    output reg  [ 7:0] o_x  [1:8],
    output reg  [ 7:0] o_px [1:8],
    output reg         o_s  [1:8],
    output reg  [ 4:0] o_qh [1:8],
    output reg  [ 3:0] o_ql [1:8],
    output reg  [ 2:0] o_qcnt [1:8],
    output reg  [ 2:0] o_qcnt_max,
    output reg  [13:0] o_rl [1:8]
);

reg        a_sp;
reg        a_vl;
reg [ 7:0] a_b  [1:8];
reg [ 7:0] a_x  [1:8];
reg [ 7:0] a_px [1:8];
reg        a_s  [1:8];
reg [ 4:0] a_qh [1:8];
reg [ 3:0] a_ql [1:8];
reg        a_ir [1:8];
reg [ 2:0] a_qcnt [1:8];

reg         b_vl;
reg  [ 7:0] b_x  [1:8];
reg  [ 7:0] b_px [1:8];
reg         b_s  [1:8];
reg  [ 4:0] b_qh [1:8];
reg  [ 3:0] b_ql [1:8];
reg  [ 2:0] b_qcnt [1:8];
reg  [ 2:0] b_qcnt_max [1:2];
reg         b_rlc[1:8];
reg  [ 2:0] b_rl [2:8];
reg         b_rllc;
reg  [ 3:0] b_rll;

reg  [13:0] rll;

function automatic logic [7:0] predictor(input [7:0] a, input [7:0] b, input [7:0] c);
    if( c>=a && c>=b ) begin
        return a>b ? b : a;
    end else if( c<=a && c<=b ) begin
        return a>b ? a : b;
    end else begin
        return a - c + b;
    end
endfunction

function automatic logic [2:0] max2(input [2:0] in1, input [2:0] in2);
    if(in1>in2)
        return in1;
    else
        return in2;
endfunction

function automatic logic [2:0] max4(input [2:0] in1, input [2:0] in2, input [2:0] in3, input [2:0] in4);
    return max2( max2(in1, in2), max2(in3, in4) );
endfunction

always @ (posedge clk)
    if(ena) begin
        a_sp <= i_sp;
        a_vl <= i_vl;
        a_s  <= i_s;
        a_qh <= i_qh;
        a_ql <= i_ql;
        a_qcnt <= i_qcnt;
        for(int i=1; i<=8; i++) begin
            a_ir[i] <= i_ql[i] == 4'd15;
            a_x[i]  <= i_x[i];
            a_b[i]  <= i_b[i];
            a_px[i] <= predictor(i_x[i-1], i_b[i], i_b[i-1]);
        end
    end else if(rst) begin
        a_sp <= '0;
        a_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        automatic logic [2:0] rl = {2'd0, a_ir[1]};
        b_vl <= a_vl;
        b_x <= a_x;
        b_s  <= a_s;
        b_qh <= a_qh;
        b_ql <= a_ql;
        b_qcnt <= a_qcnt;
        
        b_rlc[1] <= ~a_sp;
        b_rlc[2] <= ~a_sp & a_ir[1];
        b_rlc[3] <= ~a_sp & a_ir[1] & a_ir[2];
        b_rlc[4] <= ~a_sp & a_ir[1] & a_ir[2] & a_ir[3];
        b_rlc[5] <= ~a_sp & a_ir[1] & a_ir[2] & a_ir[3] & a_ir[4];
        b_rlc[6] <= ~a_sp & a_ir[1] & a_ir[2] & a_ir[3] & a_ir[4] & a_ir[5];
        b_rlc[7] <= ~a_sp & a_ir[1] & a_ir[2] & a_ir[3] & a_ir[4] & a_ir[5] & a_ir[6];
        b_rlc[8] <= ~a_sp & a_ir[1] & a_ir[2] & a_ir[3] & a_ir[4] & a_ir[5] & a_ir[6] & a_ir[7];
        b_rllc   <= ~a_sp & a_ir[1] & a_ir[2] & a_ir[3] & a_ir[4] & a_ir[5] & a_ir[6] & a_ir[7] & a_ir[8];
        
        for(int i=2; i<=7; i++) begin
            b_rl[i] <= rl;
            rl = a_ir[i] ? rl + 3'd1 : 3'd0;
        end
        b_rl[8] <= rl;
        b_rll <= a_ir[8] ? {1'b0, rl} + 4'd1 : 4'd0;

        for(int i=1; i<=8; i++) begin
            b_px[i] <= (a_ql[i]==4'd13) ? a_b[i] : a_px[i];
        end
        b_qcnt_max[1] <= max4(a_qcnt[1], a_qcnt[2], a_qcnt[3], a_qcnt[4]);
        b_qcnt_max[2] <= max4(a_qcnt[5], a_qcnt[6], a_qcnt[7], a_qcnt[8]);
    end else if(rst) begin
        b_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        o_vl <= b_vl;
        o_x <=  b_x;
        o_px <=  b_px;
        o_s <=  b_s;
        o_qh <=  b_qh;
        o_ql <= b_ql;
        o_qcnt <= b_qcnt;
        o_qcnt_max <= max2(b_qcnt_max[1], b_qcnt_max[2]);
        
        o_rl[1] <= b_rlc[1] ? rll : '0;
        for(int i=2; i<=7; i++) begin
            o_rl[i] <= (b_rlc[i] ? rll : '0) + {11'd0, b_rl[i]};
        end
        o_rl[8] <= (b_rlc[8] ? rll : '0) + {11'd0, b_rl[8]} + {13'd0, b_qh[8][4]};
        
        rll <= (b_rllc ? rll : '0) + {10'd0, b_rll};
    end else if(rst) begin
        o_vl <= '0;
    end

endmodule
