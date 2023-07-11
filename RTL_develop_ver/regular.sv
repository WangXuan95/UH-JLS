`timescale 1 ns/1 ns

// 11 stage pipeline
module regular(
    input  wire        rst,
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

localparam [8:0] LIMIT = 9'd23;

function automatic logic signed [9:0] clip(input [7:0] px, input [7:0] c, input s);
    logic signed [9:0] pxc, ec;
    ec = $signed({c[7],c[7],c});
    pxc = $signed({2'h0, px}) + ( s ? -ec : ec );
    if( pxc > $signed(10'd255) )
        pxc = $signed(10'd255);
    else if( pxc < $signed(10'd0) )
        pxc = $signed(10'd0);
    return s ? pxc : -pxc;
endfunction

function automatic logic signed [8:0] modrange(input signed [9:0] val);
    automatic logic signed [9:0] new_val = val;
    if( new_val < $signed(10'd0) )
        new_val += $signed(10'd256);
    if( new_val >= $signed(10'd128) )
        new_val -= $signed(10'd256);
    return new_val[8:0];
endfunction

function automatic logic [3:0] get_k(input [6:0] N, input [11:0] A);
    automatic logic [17:0] Nt;
    automatic logic [17:0] At;
    automatic logic [ 3:0] k;
    Nt = {11'h0, N};
    At = { 6'h0, A};
    for(k=4'h0; k<4'd12; k++) begin
        if((Nt<<k)>=At)
            break;
    end
    return k;
endfunction

function automatic logic [6:0] N_update(input [6:0] N);
    N_update = N;
    if(N[6])
        N_update >>>= 1;
    N_update += 7'd1;
endfunction

function automatic logic [16:0] C_B_update(input reset, input [6:0] N, input [7:0] C, input signed [6:0] B, input signed [8:0] err);
    automatic logic        [1:0] csel = 2'd1;
    automatic logic signed [8:0] Bt;
    automatic logic        [7:0] Ct;
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
    end else if( Bt > $signed(9'd0) ) begin
        Bt -= $signed({2'd0,N});
        if( Bt > $signed(9'd0) )
            Bt = $signed(9'd0);
        if( Ct != 8'd127 ) begin
            Ct++;
            csel = 2'd2;
        end
    end
    return {csel, Ct, Bt[6:0]};
endfunction

function automatic logic [11:0] A_update(input reset, input [11:0] A, input [8:0] abs_err);
    A_update = A + {3'd0, abs_err};
    if(reset)
        A_update >>>= 1;
    return A_update;
endfunction

reg        [ 6:0] Nram [28];
reg        [11:0] Aram [28];
reg signed [ 6:0] Bram [28];
reg        [ 7:0] Cram [28];

reg               a_vl;
reg signed [ 9:0] a_sx;
reg        [ 7:0] a_px;
reg               a_s;
reg        [ 4:0] a_qh;
reg        [ 6:0] a_N;
reg        [ 6:0] a_Nn;

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
reg signed [ 6:0] e_B;
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
reg        [11:0] g_A;
reg        [11:0] g_An;
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





// -------------------------------------------- stage1: calc sx, update N -------------------------------------------------------
always @ (posedge clk) begin
    automatic logic [6:0] Ntmp, Nnew;
    a_vl <= rst ? 1'b0 : i_vl;
    a_sx <= i_s ? -$signed({2'h0,i_x}) : $signed({2'h0,i_x});
    a_px <= i_px;
    a_s  <= i_s;
    a_qh <= i_qh;
    Ntmp = Nram[i_qh];
    Nnew = N_update(Ntmp);
    if(rst)
        Nram <= '{28{7'd1}};
    else if(i_vl)
        Nram[i_qh] <= Nnew;
    a_N <= Ntmp;
    a_Nn <= Nnew;
end
// -------------------------------------------- end of stage1  -----------------------------------------------------------------






always @ (posedge clk) begin
    b_vl <= rst ? 1'b0 : a_vl;
    b_sx <= a_sx;
    b_px <= a_px;
    b_s <= a_s;
    b_qh <= a_qh;
    b_N <= a_N;
    b_Nn <= a_Nn;
    b_C <= d_col_c ? d_Cn : Cram[a_qh];   // forward selection
end





// -------------------------------------------- stage2: calc errval candidate (look-ahead on C[n]) -------------------------------------------------------
always @ (posedge clk) begin
    automatic logic [7:0] Ctmp;
    Ctmp = d_col_b ? d_Cn : b_C;          // forward selection
    c_B <= d_col_b ? d_Bn : Bram[b_qh];   // forward selection
    c_vl <= rst ? 1'b0 : b_vl;
    c_col_a <= b_vl && b_qh==a_qh;
    c_qh <= b_qh;
    c_N <= b_N;
    c_Nn <= b_Nn;
    c_C <= Ctmp;
    c_err_cand[0] <= modrange( b_sx + clip(b_px, Ctmp-8'd1, b_s) );
    c_err_cand[1] <= modrange( b_sx + clip(b_px, Ctmp     , b_s) );
    c_err_cand[2] <= modrange( b_sx + clip(b_px, Ctmp+8'd1, b_s) );
end
// -------------------------------------------- end of stage2  -----------------------------------------------------------------







// -------------------------------------------- stage3: update A, B, C -------------------------------------------------------
always @ (posedge clk) begin
    automatic logic        [ 1:0] sel;
    automatic logic signed [ 8:0] err;
    automatic logic        [ 7:0] Ctmp, Cn;
    automatic logic signed [ 6:0] Btmp, Bn;
    err = c_err_cand[d_sel];            // look-ahead selection
    Ctmp = c_C + {6'd0, d_sel} - 8'd1;  // look-ahead selection
    Btmp = d_col_a ? d_Bn : c_B;        // forward selection
    {sel, Cn, Bn} = C_B_update(c_N[6], c_Nn, Ctmp, Btmp, err);
    d_vl <= rst ? 1'b0 : c_vl;
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
// -------------------------------------------- end of stage3  -----------------------------------------------------------------





// -------------------------------------------- stage4: write C,B -------------------------------------------------------
always @ (posedge clk) begin
    e_vl <= rst ? 1'b0 : d_vl;
    e_col_a <= d_col_a;
    e_qh <= d_qh;
    e_err <= d_err;
    e_N <= d_N;
    e_2BgeN <= $unsigned(-$signed({d_B,1'b0})) >= {1'b0,d_N};
    if(rst) begin
        Cram <= '{28{'0}};
        Bram <= '{28{'0}};
    end else if(d_vl) begin
        Cram[d_qh] <= d_Cn;
        Bram[d_qh] <= d_Bn;
    end
end
// -------------------------------------------- end of stage4  -----------------------------------------------------------------







always @ (posedge clk) begin
    f_vl <= rst ? 1'b0 : e_vl;
    f_col_a <= e_col_a;
    f_qh <= e_qh;
    f_err <= e_err;
    f_abs_err <= e_err[8] ? $unsigned(-e_err) : $unsigned(e_err);
    f_N <= e_N;
    f_2BgeN <= e_2BgeN;
end






always @ (posedge clk) begin
    automatic logic [11:0] Atmp;
    Atmp = g_col_a ? g_An : Aram[f_qh];
    g_vl <= rst ? 1'b0 : f_vl;
    g_col_a <= f_col_a;
    g_qh <= f_qh;
    g_N <= f_N;
    g_A <= Atmp;
    g_An <= A_update(f_N[6], Atmp, f_abs_err);
    g_err <= f_err;
    g_2BgeN <= f_2BgeN;
end





// -------------------------------------------- stage4: calc k -------------------------------------------------------
always @ (posedge clk) begin
    h_vl <= rst ? 1'b0 : g_vl;
    h_k <= get_k(g_N, g_A);
    h_err <= g_err;
    h_2BgeN <= g_2BgeN;
    if(rst)
        Aram <= '{28{12'd4}};
    else if(g_vl)
        Aram[g_qh] <= g_An;
end
// -------------------------------------------- end of stage4  -----------------------------------------------------------------




// -------------------------------------------- stage5: calc merrval -------------------------------------------------------
always @ (posedge clk) begin
    automatic logic signed [9:0] merr;
    if( h_k==4'd0 && h_2BgeN ) begin
        if( h_err >= $signed(9'd0) )
            merr = {h_err,1'b1};
        else
            merr = -$signed(10'd2)*(h_err+$signed(9'd1));
    end else begin
        if( h_err >= $signed(9'd0) )
            merr = {h_err,1'b0};
        else
            merr = -$signed({h_err,1'b1});
    end
    j_vl <= rst ? 1'b0 : h_vl;
    j_k <= h_k;
    j_merr <= merr[8:0];
end
// -------------------------------------------- end of stage5  -----------------------------------------------------------------




// -------------------------------------------- stage6: calc Golomb Coding Preprocess 1 -------------------------------------------------------
always @ (posedge clk) begin
    k_vl <= rst ? 1'b0 : j_vl;
    k_k <= j_k;
    k_merr <= j_merr;
    k_merr_sk <= (j_merr>>j_k);
end
// -------------------------------------------- end of stage6  -----------------------------------------------------------------



// -------------------------------------------- stage7: calc Golomb Coding Preprocess 2 -------------------------------------------------------
always @ (posedge clk) begin
    o_vl <= rst ? 1'b0 : k_vl;
    if(k_merr_sk < LIMIT) begin
        o_zc <= k_merr_sk[4:0] + {4'h0, k_vl};
        o_bv <= k_merr;
        o_bc <= k_k;
    end else begin
        o_zc <= LIMIT[4:0] + {4'h0, k_vl};
        o_bv <= k_merr - 9'd1;
        o_bc <= 4'd8;
    end
end
// -------------------------------------------- end of stage7  -----------------------------------------------------------------

endmodule
