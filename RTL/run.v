
//--------------------------------------------------------------------------------------------------------
// Module  : run
// Type    : synthesizable, IP's submodule
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: JPEG-LS's run-mode pixel encoding pipeline 
//           11 stage pipeline
//--------------------------------------------------------------------------------------------------------

module run (
    input  wire       rst,
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


function  signed [8:0] modrange;
    input signed [9:0] val;
    reg   signed [9:0] new_val;
begin
    new_val = val;
    if ( new_val < 10'sd0 )
        new_val = new_val + 10'sd256;
    if ( new_val >= 10'sd128 )
        new_val = new_val - 10'sd256;
    modrange = new_val[8:0];
end
endfunction


function  [ 3:0] get_k_r;
    input [ 6:0] N;
    input [12:0] A;
    input [ 0:0] q;
    reg   [18:0] Nt, At;
    integer i;
begin
    Nt = {12'h0, N};
    At = { 6'h0, A};
    get_k_r = 4'd0;
    if (q)
        At = At + {13'd0, N[6:1]};
    for (i=0; i<13; i=i+1)
        if ((Nt<<i) < At)
            get_k_r = get_k_r + 4'd1;
end
endfunction


function  [6:0] N_update;
    input [6:0] N;
begin
    N_update = N;
    if (N[6])
        N_update = (N_update >>> 1);
    N_update = N_update + 7'd1;
end
endfunction


function  [5:0] B_update;
    input [0:0] errm0, reset;
    input [5:0] B;
begin
    B_update = B;
    if (errm0)
        B_update = B_update + 6'd1;
    if (reset)
        B_update = (B_update >>> 1);
end
endfunction


function  [12:0] A_update;
    input [ 0:0] reset, aeqb;
    input [ 9:0] merr;
    input [12:0] A;
    reg   [10:0] Ap;
begin
    Ap = {1'b0, merr} + {10'd0, ~aeqb};
    A_update = A + {3'b0, Ap[10:1]};
    if (reset)
        A_update = (A_update >>> 1);
end
endfunction



reg [ 6:0] Nram [0:1];
reg [12:0] Aram [0:1];
reg [ 5:0] Bram [0:1];

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
    a_vl <= i_vl & (~rst);
    a_x <= i_x;
    a_px <= i_px;
    a_q <= i_q;
    a_s <= i_s;
    a_cn <= i_cn;
end


wire [6:0] a_N = Nram[a_q];

always @ (posedge clk) begin
    b_vl <= a_vl & (~rst);
    if (rst) begin
        Nram[0] <= 7'd1;
        Nram[1] <= 7'd1;
    end else if (a_vl)
        Nram[a_q] <= N_update(a_N);
    b_q <= a_q;
    b_N <= a_N;
    if (a_s)
        b_err <= $signed({2'h0, a_px}) - $signed({2'h0, a_x});
    else
        b_err <= $signed({2'h0, a_x}) - $signed({2'h0, a_px});
    b_cn <= a_cn;
end


always @ (posedge clk) begin
    c_vl <= b_vl & (~rst);
    c_q <= b_q;
    c_N <= b_N;
    c_err <= modrange(b_err);
    c_cn <= b_cn;
end


wire [5:0] c_B = Bram[c_q];

always @ (posedge clk) begin
    d_vl <= c_vl & (~rst);
    if (rst) begin
        Bram[0] <= 6'd0;
        Bram[1] <= 6'd0;
    end else if (c_vl)
        Bram[c_q] <= B_update((c_err<9'sd0), c_N[6], c_B);
    d_q <= c_q;
    d_N <= c_N;
    d_2BltN <= ({c_B,1'b0} < c_N);
    d_errne0 <= c_err != 9'sd0;
    d_errgt0 <= c_err >  9'sd0;
    if (c_err < 9'sd0)
        d_abserr <= $unsigned(-c_err);
    else
        d_abserr <= $unsigned( c_err);
    d_cn <= c_cn;
end


wire [12:0] d_A    = Aram[d_q];
wire [ 3:0] d_k    = get_k_r(d_N, d_A, d_q);
wire        d_map  = d_errne0 & (d_errgt0 == ((d_k==4'd0) & d_2BltN));
wire [ 9:0] d_merr = ({d_abserr, 1'b0} - {9'd0,d_q} - {9'd0,d_map});

always @ (posedge clk) begin
    e_vl <= d_vl & (~rst);
    if (rst) begin
        Aram[0] <= 13'd4;
        Aram[1] <= 13'd4;
    end else if (d_vl)
        Aram[d_q] <= A_update(d_N[6], d_q, d_merr, d_A);
    e_k <= d_k;
    e_merr <= d_merr[8:0];
    e_cn <= d_cn;
end


wire [9:0] e_merr_sk_e = (e_merr >> e_k);

always @ (posedge clk) begin
    f_vl <= e_vl & (~rst);
    f_k <= e_k;
    f_merr <= e_merr[8:0];
    f_merr_sk <= e_merr_sk_e[8:0];
    f_lm <= LIMIT - {1'b0, e_cn};
end


always @ (posedge clk) begin
    g_vl <= f_vl & (~rst);
    if (f_merr_sk < {4'd0,f_lm}) begin
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
    h_vl <= g_vl & (~rst);
    h_zc <= g_zc;
    h_bv <= g_bv;
    h_bc <= g_bc;
end


always @ (posedge clk) begin
    j_vl <= h_vl & (~rst);
    j_zc <= h_zc;
    j_bv <= h_bv;
    j_bc <= h_bc;
end


always @ (posedge clk) begin
    k_vl <= j_vl & (~rst);
    k_zc <= j_zc;
    k_bv <= j_bv;
    k_bc <= j_bc;
end


always @ (posedge clk) begin
    o_vl <= k_vl & (~rst);
    o_zc <= k_zc;
    o_bv <= k_bv;
    o_bc <= k_bc;
end

endmodule
