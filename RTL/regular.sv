`timescale 1ns/1ns

// 11 stage pipeline
module regular(
    input  wire        rstn,
    input  wire        clk,
    input  wire        i_vl,
    input  wire [ 7:0] i_x,
    input  wire [ 7:0] i_px,
    input  wire        i_s,
    input  wire [ 4:0] i_qh,
    output reg         o_vl,
    output reg  [ 4:0] o_zc,
    output reg  [ 8:0] o_bv,
    output reg  [ 3:0] o_bc
);

localparam [4:0] LIMIT = 5'd23;

function automatic logic signed [9:0] clip(input [7:0] px, input [7:0] c, input s);
    logic signed [9:0] pxc, ec;
    ec = $signed({c[7],c[7],c});
    pxc = $signed({2'h0, px}) + ( s ? -ec : ec );
    if( pxc > 10'sd255 )
        pxc = 10'sd255;
    else if( pxc < 10'sd0 )
        pxc = 10'sd0;
    return s ? pxc : -pxc;
endfunction

function automatic logic signed [8:0] modrange(input signed [9:0] val);
    logic signed [9:0] new_val = val;
    if( new_val < 10'sd0 )
        new_val += 10'sd256;
    if( new_val >= 10'sd128 )
        new_val -= 10'sd256;
    return new_val[8:0];
endfunction

function automatic logic [3:0] get_k(input [6:0] N, input [12:0] A);
    logic [18:0] Nt = {12'h0, N};
    logic [18:0] At = { 6'h0, A};
    logic [ 3:0] k = 4'd0;
    for(int ii=0; ii<13; ii++)
        if((Nt<<ii) < At)
            k++;
    return k;
endfunction

function automatic logic [6:0] N_update(input [6:0] N);
    N_update = N;
    if(N[6])
        N_update >>>= 1;
    N_update += 7'd1;
endfunction

function automatic logic [16:0] C_B_update(input reset, input [6:0] N, input [7:0] C, input signed [6:0] B, input signed [8:0] err);
    logic        [1:0] csel = 2'd1;
    logic signed [8:0] Bt;
    logic        [7:0] Ct;
    Ct = C;
    Bt = $signed({B[6], B[6], B}) + err;
    if(reset)
        Bt >>>= 1;
    if( Bt <= -$signed({2'd0,N}) ) begin
        Bt += $signed({2'd0,N});
        if( Bt <= -$signed({2'd0,N}) )
            Bt = -$signed({2'd0,N}-9'd1);
        if( Ct != 8'd128 ) begin
            Ct--;
            csel = 2'd0;
        end
    end else if( Bt > 9'sd0 ) begin
        Bt -= $signed({2'd0,N});
        if( Bt > 9'sd0 )
            Bt = 9'sd0;
        if( Ct != 8'd127 ) begin
            Ct++;
            csel = 2'd2;
        end
    end
    return {csel, Ct, Bt[6:0]};
endfunction

function automatic logic [12:0] A_update(input reset, input [12:0] A, input [8:0] abs_err);
    A_update = A + {4'd0, abs_err};
    if(reset)
        A_update >>>= 1;
    return A_update;
endfunction

reg        [ 6:0] Nram [28];
reg        [12:0] Aram [28];
reg signed [ 6:0] Bram [28];
reg        [ 7:0] Cram [28];

reg               a_vl;
reg signed [ 9:0] a_sx;
reg        [ 7:0] a_px;
reg               a_s;
reg        [ 4:0] a_qh = '0;

reg               b_vl;
reg signed [ 9:0] b_sx;
reg        [ 7:0] b_px;
reg               b_s;
reg        [ 4:0] b_qh;
reg        [ 6:0] b_N;
reg        [ 6:0] b_Nn;
reg        [ 7:0] b_C;

reg               c_vl;
reg               c_col_a;
reg        [ 4:0] c_qh;
reg        [ 6:0] c_N;
reg        [ 6:0] c_Nn;
reg signed [ 6:0] c_B;
reg        [ 7:0] c_C;
reg signed [ 8:0] c_err_cand [0:2];

reg               d_vl;
reg               d_col_a, d_col_b, d_col_c;
reg        [ 4:0] d_qh;
reg        [ 6:0] d_N;
reg signed [ 6:0] d_B;
reg        [ 7:0] d_Cn;
reg signed [ 6:0] d_Bn;
reg        [ 1:0] d_sel;
reg signed [ 8:0] d_err;

reg               e_vl;
reg               e_col_a;
reg        [ 4:0] e_qh;
reg        [ 6:0] e_N;
reg signed [ 8:0] e_err;
reg               e_2BgeN;

reg               f_vl;
reg               f_col_a;
reg        [ 4:0] f_qh;
reg        [ 6:0] f_N;
reg signed [ 8:0] f_err;
reg        [ 8:0] f_abs_err;
reg               f_2BgeN;

reg               g_vl;
reg               g_col_a;
reg        [ 4:0] g_qh;
reg        [ 6:0] g_N;
reg        [12:0] g_A;
reg        [12:0] g_An;
reg signed [ 8:0] g_err;
reg               g_2BgeN;

reg               h_vl;
reg        [ 3:0] h_k;
reg signed [ 8:0] h_err;
reg               h_2BgeN;

reg               j_vl;
reg        [ 3:0] j_k;
reg        [ 8:0] j_merr;

reg               k_vl;
reg        [ 3:0] k_k;
reg        [ 8:0] k_merr;
reg        [ 8:0] k_merr_sk;


always @ (posedge clk) begin
    a_vl <= rstn & i_vl;
    a_sx <= i_s ? -$signed({2'h0,i_x}) : $signed({2'h0,i_x});
    a_px <= i_px;
    a_s  <= i_s;
    if(rstn)
        a_qh <= i_qh;
    else
        a_qh <= a_qh < 5'd27 ? a_qh + 5'd1 : 5'd0;
end


always @ (posedge clk) begin
    automatic logic [6:0] Ntmp, Nnew;
    b_vl <= rstn & a_vl;
    b_sx <= a_sx;
    b_px <= a_px;
    b_s <= a_s;
    b_qh <= a_qh;
    Ntmp = Nram[a_qh];
    Nnew = N_update(Ntmp);
    if(~rstn | a_vl)
        Nram[a_qh] <= a_vl ? Nnew : 7'd1;
    b_N <= Ntmp;
    b_Nn <= Nnew;
    b_C <= d_col_c ? d_Cn : Cram[a_qh];   // forward selection
end


always @ (posedge clk) begin
    automatic logic [7:0] Ctmp;
    Ctmp = d_col_b ? d_Cn : b_C;          // forward selection
    c_B <= d_col_b ? d_Bn : Bram[b_qh];   // forward selection
    c_vl <= rstn & b_vl;
    c_col_a <= b_vl && b_qh==a_qh;
    c_qh <= b_qh;
    c_N <= b_N;
    c_Nn <= b_Nn;
    c_C <= Ctmp;
    c_err_cand[0] <= modrange( b_sx + clip(b_px, Ctmp-8'd1, b_s) );
    c_err_cand[1] <= modrange( b_sx + clip(b_px, Ctmp     , b_s) );
    c_err_cand[2] <= modrange( b_sx + clip(b_px, Ctmp+8'd1, b_s) );
end


always @ (posedge clk) begin
    automatic logic        [ 1:0] sel;
    automatic logic signed [ 8:0] err;
    automatic logic        [ 7:0] Ctmp, Cn;
    automatic logic signed [ 6:0] Btmp, Bn;
    err = c_err_cand[d_sel];            // look-ahead selection
    Ctmp = c_C + {6'd0, d_sel} - 8'd1;  // look-ahead selection
    Btmp = d_col_a ? d_Bn : c_B;        // forward selection
    {sel, Cn, Bn} = C_B_update(c_N[6], c_Nn, Ctmp, Btmp, err);
    d_vl <= rstn & c_vl;
    d_col_a <= c_col_a;
    d_col_b <= c_vl && c_qh==a_qh;
    d_col_c <= c_vl && c_qh==i_qh;
    d_sel <= c_col_a ? sel : 2'd1;
    d_N <= c_N;
    d_B <= Btmp;
    d_Cn <= Cn;
    d_Bn <= Bn;
    d_err <= err;
    d_qh <= c_qh;
end


always @ (posedge clk) begin
    e_vl <= rstn & d_vl;
    e_col_a <= d_col_a;
    e_qh <= d_qh;
    e_err <= d_err;
    e_N <= d_N;
    e_2BgeN <= $unsigned(-$signed({d_B,1'b0})) >= {1'b0,d_N};
    if(~rstn | d_vl) begin
        Cram[d_qh] <= d_vl ? d_Cn : '0;
        Bram[d_qh] <= d_vl ? d_Bn : '0;
    end
end


always @ (posedge clk) begin
    f_vl <= rstn & e_vl;
    f_col_a <= e_col_a;
    f_qh <= e_qh;
    f_err <= e_err;
    f_abs_err <= e_err[8] ? $unsigned(-e_err) : $unsigned(e_err);
    f_N <= e_N;
    f_2BgeN <= e_2BgeN;
end


always @ (posedge clk) begin
    automatic logic [12:0] Atmp;
    Atmp = g_col_a ? g_An : Aram[f_qh];
    g_vl <= rstn & f_vl;
    g_col_a <= f_col_a;
    g_qh <= f_qh;
    g_N <= f_N;
    g_A <= Atmp;
    g_An <= A_update(f_N[6], Atmp, f_abs_err);
    g_err <= f_err;
    g_2BgeN <= f_2BgeN;
end


always @ (posedge clk) begin
    h_vl <= rstn & g_vl;
    h_k <= get_k(g_N, g_A);
    h_err <= g_err;
    h_2BgeN <= g_2BgeN;
    if(~rstn | g_vl)
        Aram[g_qh] <= g_vl ? g_An : 12'd4;
end


always @ (posedge clk) begin
    automatic logic signed [9:0] merr;
    if( h_k==4'd0 && h_2BgeN ) begin
        if( h_err >= 9'sd0 )
            merr = {h_err,1'b1};
        else
            merr = -10'sd2*(h_err+10'sd1);
    end else begin
        if( h_err >= 9'sd0 )
            merr = {h_err,1'b0};
        else
            merr = -$signed({h_err,1'b1});
    end
    j_vl <= rstn & h_vl;
    j_k <= h_k;
    j_merr <= merr[8:0];
end


always @ (posedge clk) begin
    k_vl <= rstn & j_vl;
    k_k <= j_k;
    k_merr <= j_merr;
    k_merr_sk <= (j_merr>>j_k);
end


always @ (posedge clk) begin
    o_vl <= rstn & k_vl;
    if(k_merr_sk < {4'd0,LIMIT}) begin
        o_zc <= k_merr_sk[4:0] + {4'h0, k_vl};
        o_bv <= k_merr;
        o_bc <= k_k;
    end else begin
        o_zc <= LIMIT + {4'h0, k_vl};
        o_bv <= k_merr - 9'd1;
        o_bc <= 4'd8;
    end
end

endmodule
