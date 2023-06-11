
//--------------------------------------------------------------------------------------------------------
// Module  : regular
// Type    : synthesizable, IP's submodule
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: JPEG-LS's regular-mode pixel encoding pipeline 
//           11 stage pipeline
//--------------------------------------------------------------------------------------------------------

module regular (
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


localparam [4:0] LIMIT = 5'd23;


function signed [9:0] clip;
    input       [7:0] px, c;
    input       [0:0] s;
begin
    clip = $signed({c[7],c[7],c});
    clip = $signed({2'h0, px}) + ( s ? -clip : clip );
    if ( clip > 10'sd255 )
        clip = 10'sd255;
    else if ( clip < 10'sd0 )
        clip = 10'sd0;
    clip = s ? clip : -clip;
end
endfunction


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


function  [ 3:0] get_k;
    input [ 6:0] N;
    input [12:0] A;
    reg   [18:0] Nt;
    reg   [18:0] At;
    integer i;
begin
    Nt = {12'h0, N};
    At = { 6'h0, A};
    get_k = 4'd0;
    for (i=0; i<13; i=i+1)
        if ((Nt<<i) < At)
            get_k = get_k + 4'd1;
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


function        [16:0] C_B_update;
    input        [0:0] reset;
    input        [6:0] N;
    input        [7:0] C;
    input signed [6:0] B;
    input signed [8:0] err;
    reg          [1:0] csel;
    reg   signed [8:0] Bt;
    reg          [7:0] Ct;
begin
    csel = 2'd1;
    Ct = C;
    Bt = $signed({B[6], B[6], B}) + err;
    if (reset)
        Bt = (Bt >>> 1);
    if ( Bt <= -$signed({2'd0,N}) ) begin
        Bt = Bt + $signed({2'd0,N});
        if ( Bt <= -$signed({2'd0,N}) )
            Bt = -$signed({2'd0,N}-9'd1);
        if ( Ct != 8'd128 ) begin
            Ct = Ct - 8'd1;
            csel = 2'd0;
        end
    end else if ( Bt > 9'sd0 ) begin
        Bt = Bt - $signed({2'd0,N});
        if ( Bt > 9'sd0 )
            Bt = 9'sd0;
        if ( Ct != 8'd127 ) begin
            Ct = Ct + 8'd1;
            csel = 2'd2;
        end
    end
    C_B_update = {csel, Ct, Bt[6:0]};
end
endfunction


function  [12:0] A_update;
    input [ 0:0] reset;
    input [12:0] A;
    input [ 8:0] abs_err;
begin
    A_update = A + {4'd0, abs_err};
    if (reset)
        A_update = (A_update >>> 1);
end
endfunction



reg        [ 6:0] Nram [0:27];
reg        [12:0] Aram [0:27];
reg signed [ 6:0] Bram [0:27];
reg        [ 7:0] Cram [0:27];

reg               a_vl;
reg signed [ 9:0] a_sx;
reg        [ 7:0] a_px;
reg               a_s;
reg        [ 4:0] a_qh = 5'd0;

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
    a_vl <= i_vl & (~rst);
    a_sx <= i_s ? -$signed({2'h0,i_x}) : $signed({2'h0,i_x});
    a_px <= i_px;
    a_s  <= i_s;
    if (rst)
        a_qh <= (a_qh < 5'd27) ? (a_qh + 5'd1) : 5'd0;
    else
        a_qh <= i_qh;
end


wire [6:0] a_N  = Nram[a_qh];
wire [6:0] a_Nn = N_update(a_N);

always @ (posedge clk) begin
    b_vl <= a_vl & (~rst);
    b_sx <= a_sx;
    b_px <= a_px;
    b_s <= a_s;
    b_qh <= a_qh;
    if (a_vl | rst)
        Nram[a_qh] <= a_vl ? a_Nn : 7'd1;
    b_N <= a_N;
    b_Nn <= a_Nn;
    b_C <= d_col_c ? d_Cn : Cram[a_qh];   // forward selection
end


wire [7:0] b_Ct = d_col_b ? d_Cn : b_C;   // forward selection

always @ (posedge clk) begin
    c_B <= d_col_b ? d_Bn : Bram[b_qh];   // forward selection
    c_vl <= b_vl & (~rst);
    c_col_a <= b_vl && b_qh==a_qh;
    c_qh <= b_qh;
    c_N <= b_N;
    c_Nn <= b_Nn;
    c_C <= b_Ct;
    c_err_cand[0] <= modrange( b_sx + clip(b_px, b_Ct-8'd1, b_s) );
    c_err_cand[1] <= modrange( b_sx + clip(b_px, b_Ct     , b_s) );
    c_err_cand[2] <= modrange( b_sx + clip(b_px, b_Ct+8'd1, b_s) );
end


wire        [1:0] c_sel;
wire signed [8:0] c_err = c_err_cand[d_sel];               // look-ahead selection
wire        [7:0] c_Ct  = c_C + {6'd0, d_sel} - 8'd1;      // look-ahead selection
wire        [7:0] c_Cn;
wire signed [6:0] c_Bt  = d_col_a ? d_Bn : c_B;            // forward selection
wire signed [6:0] c_Bn;

assign {c_sel, c_Cn, c_Bn} = C_B_update(c_N[6], c_Nn, c_Ct, c_Bt, c_err);

always @ (posedge clk) begin
    d_vl <= c_vl & (~rst);
    d_col_a <= c_col_a;
    d_col_b <= c_vl && c_qh==a_qh;
    d_col_c <= c_vl && c_qh==i_qh;
    d_sel <= c_col_a ? c_sel : 2'd1;
    d_N <= c_N;
    d_B <= c_Bt;
    d_Cn <= c_Cn;
    d_Bn <= c_Bn;
    d_err <= c_err;
    d_qh <= c_qh;
end


always @ (posedge clk) begin
    e_vl <= d_vl & (~rst);
    e_col_a <= d_col_a;
    e_qh <= d_qh;
    e_err <= d_err;
    e_N <= d_N;
    e_2BgeN <= ( $unsigned(-$signed({d_B,1'b0})) >= {1'b0,d_N} );
    if (d_vl | rst) begin
        Cram[d_qh] <= d_vl ? d_Cn : 8'd0;
        Bram[d_qh] <= d_vl ? d_Bn : 7'd0;
    end
end


always @ (posedge clk) begin
    f_vl <= e_vl & (~rst);
    f_col_a <= e_col_a;
    f_qh <= e_qh;
    f_err <= e_err;
    f_abs_err <= e_err[8] ? $unsigned(-e_err) : $unsigned(e_err);
    f_N <= e_N;
    f_2BgeN <= e_2BgeN;
end


wire [12:0] f_At = g_col_a ? g_An : Aram[f_qh];

always @ (posedge clk) begin
    g_vl <= f_vl & (~rst);
    g_col_a <= f_col_a;
    g_qh <= f_qh;
    g_N <= f_N;
    g_A <= f_At;
    g_An <= A_update(f_N[6], f_At, f_abs_err);
    g_err <= f_err;
    g_2BgeN <= f_2BgeN;
end


always @ (posedge clk) begin
    h_vl <= g_vl & (~rst);
    h_k <= get_k(g_N, g_A);
    h_err <= g_err;
    h_2BgeN <= g_2BgeN;
    if (g_vl | rst)
        Aram[g_qh] <= g_vl ? g_An : 12'd4;
end


wire signed [9:0] h_merr = ( h_k==4'd0 && h_2BgeN ) ?
                             ( (h_err >= 9'sd0) ? {h_err,1'b1} : (-10'sd2*(h_err+10'sd1)) ) :
                             ( (h_err >= 9'sd0) ? {h_err,1'b0} : (-$signed({h_err,1'b1})) ) ;

always @ (posedge clk) begin
    j_vl <= h_vl & (~rst);
    j_k <= h_k;
    j_merr <= h_merr[8:0];
end


always @ (posedge clk) begin
    k_vl <= j_vl & (~rst);
    k_k <= j_k;
    k_merr <= j_merr;
    k_merr_sk <= (j_merr>>j_k);
end


always @ (posedge clk) begin
    o_vl <= k_vl & (~rst);
    if (k_merr_sk < {4'd0,LIMIT}) begin
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
