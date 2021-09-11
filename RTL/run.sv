`timescale 1ns/1ns

// 11 stage pipeline
module run(
    input  wire       rstn,
    input  wire       clk,
    input  wire       i_vl,
    input  wire [7:0] i_x,
    input  wire [7:0] i_px,
    input  wire       i_s,
    input  wire       i_q,
    input  wire [3:0] i_cn,
    output reg        o_vl,
    output reg  [4:0] o_zc,
    output reg  [8:0] o_bv,
    output reg  [3:0] o_bc
);

localparam [4:0] LIMIT = 5'd23;

function automatic logic signed [8:0] modrange(input signed [9:0] val);
    automatic logic signed [9:0] new_val = val;
    if( new_val < $signed(10'd0) )
        new_val += $signed(10'd256);
    if( new_val >= $signed(10'd128) )
        new_val -= $signed(10'd256);
    return new_val[8:0];
endfunction

function automatic logic [3:0] get_k_r(input [6:0] N, input [12:0] A, input q);
    logic [18:0] Nt = {12'h0, N};
    logic [18:0] At = { 6'h0, A};
    logic [ 3:0] k = 4'd0;
    if(q)
        At += {13'd0, N[6:1]};
    for(int ii=0; ii<13; ii++)
        if((Nt<<ii) < At)
            k++;
    return k;
endfunction

function automatic logic [6:0] N_update(input [6:0] N);
    automatic logic [6:0] Nt;
    Nt = N;
    if(N[6])
        Nt  >>>= 1;
    return Nt + 7'd1;
endfunction

function automatic logic [5:0] B_update(input errm0, input reset, input [5:0] B);
    automatic logic [5:0] Bt;
    Bt = B;
    if(errm0)
        Bt++;
    if(reset)
        Bt >>>= 1;
    return Bt;
endfunction

function automatic logic [12:0] A_update(input reset, input aeqb, input [9:0] merr, input [12:0] A);
    automatic logic [10:0] Ap;
    automatic logic [12:0] At;
    Ap = {1'b0, merr} + {10'd0, ~aeqb};
    At = A + {3'b0, Ap[10:1]};
    if(reset)
        At >>>= 1;
    return At;
endfunction


reg [ 6:0] Nram [2];
reg [12:0] Aram [2];
reg [ 5:0] Bram [2];

reg              a_vl;
reg        [7:0] a_x;
reg        [7:0] a_px;
reg              a_q;
reg              a_s;
reg        [3:0] a_cn;

reg              b_vl;
reg              b_q;
reg        [6:0] b_N;
reg signed [9:0] b_err;
reg        [3:0] b_cn;

reg              c_vl;
reg              c_q;
reg        [6:0] c_N;
reg signed [8:0] c_err;
reg        [3:0] c_cn;

reg              d_vl;
reg              d_q;
reg        [6:0] d_N;
reg              d_2BltN;
reg              d_errne0;
reg              d_errgt0;
reg        [8:0] d_abserr;
reg        [3:0] d_cn;

reg              e_vl;
reg        [3:0] e_k;
reg        [9:0] e_merr;
reg        [3:0] e_cn;

reg              f_vl;
reg        [3:0] f_k;
reg        [8:0] f_merr;
reg        [8:0] f_merr_sk;
reg        [4:0] f_lm;

reg         g_vl;
reg  [ 4:0] g_zc;
reg  [ 8:0] g_bv;
reg  [ 3:0] g_bc;

reg         h_vl;
reg  [ 4:0] h_zc;
reg  [ 8:0] h_bv;
reg  [ 3:0] h_bc;

reg         j_vl;
reg  [ 4:0] j_zc;
reg  [ 8:0] j_bv;
reg  [ 3:0] j_bc;

reg         k_vl;
reg  [ 4:0] k_zc;
reg  [ 8:0] k_bv;
reg  [ 3:0] k_bc;


always @ (posedge clk) begin
    a_vl <= rstn & i_vl;
    a_x <= i_x;
    a_px <= i_px;
    a_q <= i_q;
    a_s <= i_s;
    a_cn <= i_cn;
end


always @ (posedge clk) begin
    automatic logic [6:0] Nt;
    b_vl <= rstn & a_vl;
    Nt = Nram[a_q];
    if(~rstn)
        Nram <= '{2{7'd1}};
    else if(a_vl)
        Nram[a_q] <= N_update(Nt);
    b_q <= a_q;
    b_N <= Nt;
    if(a_s)
        b_err <= $signed({2'h0, a_px}) - $signed({2'h0, a_x});
    else
        b_err <= $signed({2'h0, a_x}) - $signed({2'h0, a_px});
    b_cn <= a_cn;
end


always @ (posedge clk) begin
    c_vl <= rstn & b_vl;
    c_q <= b_q;
    c_N <= b_N;
    c_err <= modrange(b_err);
    c_cn <= b_cn;
end


always @ (posedge clk) begin
    automatic logic [ 5:0] Bt;
    d_vl <= rstn & c_vl;
    Bt = Bram[c_q];
    if(~rstn)
        Bram <= '{2{6'd0}};
    else if(c_vl)
        Bram[c_q] <= B_update(c_err<$signed(9'd0), c_N[6], Bt);
    d_q <= c_q;
    d_N <= c_N;
    d_2BltN <= {Bt,1'b0} < c_N;
    d_errne0 <= c_err != $signed(9'd0);
    d_errgt0 <= c_err >  $signed(9'd0);
    if(c_err<$signed(9'd0))
        d_abserr <= $unsigned(-c_err);
    else
        d_abserr <= $unsigned( c_err);
    d_cn <= c_cn;
end


always @ (posedge clk) begin
    automatic logic [12:0] At;
    automatic logic [ 3:0] k;
    automatic logic        map;
    automatic logic [ 9:0] merr;
    e_vl <= rstn & d_vl;
    At = Aram[d_q];
    k = get_k_r(d_N, At, d_q);
    map = d_errne0 & (d_errgt0==((k==4'd0) & d_2BltN));
    merr = {d_abserr, 1'b0} - {9'd0,d_q} - {9'd0,map};
    if(~rstn)
        Aram <= '{2{13'd4}};
    else if(d_vl)
        Aram[d_q] <= A_update(d_N[6], d_q, merr, At);
    e_k <= k;
    e_merr <= merr[8:0];
    e_cn <= d_cn;
end


always @ (posedge clk) begin
    automatic logic [9:0] merr_sk_e;
    f_vl <= rstn & e_vl;
    f_k <= e_k;
    f_merr <= e_merr[8:0];
    merr_sk_e = (e_merr>>e_k);
    f_merr_sk <= merr_sk_e[8:0];
    f_lm <= LIMIT - {1'b0, e_cn};
end


always @ (posedge clk) begin
    g_vl <= rstn & f_vl;
    if(f_merr_sk < {4'd0,f_lm}) begin
        g_zc <= f_merr_sk[4:0] + {4'h0, f_vl};
        g_bv <= f_merr;
        g_bc <= f_k;
    end else begin
        g_zc <= f_lm + {4'h0, f_vl};
        g_bv <= f_merr - 9'd1;
        g_bc <= 4'd8;
    end
end


always @ (posedge clk) begin
    h_vl <= rstn & g_vl;
    h_zc <= g_zc;
    h_bv <= g_bv;
    h_bc <= g_bc;
end


always @ (posedge clk) begin
    j_vl <= rstn & h_vl;
    j_zc <= h_zc;
    j_bv <= h_bv;
    j_bc <= h_bc;
end


always @ (posedge clk) begin
    k_vl <= rstn & j_vl;
    k_zc <= j_zc;
    k_bv <= j_bv;
    k_bc <= j_bc;
end


always @ (posedge clk) begin
    o_vl <= rstn & k_vl;
    o_zc <= k_zc;
    o_bv <= k_bv;
    o_bc <= k_bc;
end

endmodule
