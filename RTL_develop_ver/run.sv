`timescale 1 ns/1 ns

// 11 stage pipeline
module run(
    input  wire        rst,
    input  wire        clk,
    input  wire        i_vl,
    input  wire [ 7:0] i_x,
    input  wire [ 7:0] i_px,
    input  wire        i_lc,
    input  wire        i_aeqb,
    input  wire        i_agtb,
    input  wire [13:0] i_rl,
    output reg         o_vl,
    output reg  [ 4:0] o_oc,
    output reg  [14:0] o_pv,
    output reg  [ 3:0] o_pc,
    output reg  [ 4:0] o_zc,
    output reg  [ 8:0] o_bv,
    output reg  [ 3:0] o_bc
);
function automatic logic signed [8:0] modrange(input signed [9:0] val);
    automatic logic signed [9:0] new_val = val;
    if( new_val < $signed(10'd0) )    // TODO add cases
        new_val += $signed(10'd256);
    if( new_val >= $signed(10'd128) )
        new_val -= $signed(10'd256);
    return new_val[8:0];
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

function automatic logic [11:0] A_update(input reset, input aeqb, input [9:0] merr, input [11:0] A);
    automatic logic [10:0] Ap;
    automatic logic [11:0] At;
    Ap = {1'b0, merr} + {10'd0, ~aeqb};
    At = A + {2'b0, Ap[10:1]};
    if(reset)
        At >>>= 1;
    return At;
endfunction

function automatic logic [3:0] get_k_r(input [6:0] N, input [11:0] A, input q);
    automatic logic [17:0] Nt;
    automatic logic [17:0] At;
    automatic logic [ 3:0] k;
    Nt = {11'h0, N};
    At = { 6'h0, A};
    if(q)
        At += {12'd0, N[6:1]};
    for(k=4'h0; k<4'd12; k++) begin
        if((Nt<<k)>=At)
            break;
    end
    return k;
endfunction


reg   [ 6:0] Nram [2];
reg   [11:0] Aram [2];
reg   [ 5:0] Bram [2];

reg              a_vl;
reg       [ 7:0] a_x;
reg       [ 7:0] a_px;
reg              a_lc;
reg              a_aeqb;
reg              a_agtb;
reg       [13:0] a_rl;

reg              b_vl;
reg              b_nlc;
reg              b_aeqb;
reg        [6:0] b_N;
reg signed [9:0] b_err;

reg              c_vl;
reg              c_nlc;
reg              c_aeqb;
reg        [6:0] c_N;
reg signed [8:0] c_err;

reg              d_vl;
reg              d_nlc;
reg              d_aeqb;
reg        [6:0] d_N;
reg              d_2BltN;
reg              d_errne0;
reg              d_errgt0;
reg        [8:0] d_abserr;

reg              e_vl;
reg              e_nlc;
reg        [3:0] e_k;
reg        [9:0] e_merr;

reg              f_vl;
reg              f_nlc;
reg        [3:0] f_k;
reg        [8:0] f_merr;
reg        [8:0] f_merr_sk;
wire      [ 4:0] f_oc;
wire      [14:0] f_pv;
wire      [ 3:0] f_pc;
wire      [ 4:0] f_lm;

reg         g_vl;
reg  [ 4:0] g_oc;
reg  [14:0] g_pv;
reg  [ 3:0] g_pc;
reg  [ 4:0] g_zc;
reg  [ 8:0] g_bv;
reg  [ 3:0] g_bc;

reg         h_vl;
reg  [ 4:0] h_oc;
reg  [14:0] h_pv;
reg  [ 3:0] h_pc;
reg  [ 4:0] h_zc;
reg  [ 8:0] h_bv;
reg  [ 3:0] h_bc;

reg         j_vl;
reg  [ 4:0] j_oc;
reg  [14:0] j_pv;
reg  [ 3:0] j_pc;
reg  [ 4:0] j_zc;
reg  [ 8:0] j_bv;
reg  [ 3:0] j_bc;

reg         k_vl;
reg  [ 4:0] k_oc;
reg  [14:0] k_pv;
reg  [ 3:0] k_pc;
reg  [ 4:0] k_zc;
reg  [ 8:0] k_bv;
reg  [ 3:0] k_bc;


always @ (posedge clk) begin
    a_vl <= rst ? 1'b0 : i_vl;
    a_x <= i_x;
    a_px <= i_px;
    a_lc <= i_lc;
    a_aeqb <= i_aeqb;
    a_agtb <= i_agtb;
    a_rl <= i_rl;
end





always @ (posedge clk) begin
    automatic logic [6:0] Nt;
    b_vl <= rst ? 1'b0 : a_vl;
    b_nlc <= rst ? 1'b0 : (a_vl & ~a_lc);
    Nt = Nram[a_aeqb];
    if(rst)
        Nram <= '{2{7'd1}};
    else if(a_vl & ~a_lc)
        Nram[a_aeqb] <= N_update(Nt);
    b_aeqb <= a_aeqb;
    b_N <= Nt;
    if(a_agtb)
        b_err <= $signed({2'h0, a_px}) - $signed({2'h0, a_x});
    else
        b_err <= $signed({2'h0, a_x}) - $signed({2'h0, a_px});
end




always @ (posedge clk) begin
    c_vl <= rst ? 1'b0 : b_vl;
    c_nlc <= rst ? 1'b0 : b_nlc;
    c_aeqb <= b_aeqb;
    c_N <= b_N;
    c_err <= modrange(b_err);
end




always @ (posedge clk) begin
    automatic logic [ 5:0] Bt;
    d_vl <= rst ? 1'b0 : c_vl;
    d_nlc <= rst ? 1'b0 : c_nlc;
    Bt = Bram[c_aeqb];
    if(rst)
        Bram <= '{2{6'd0}};
    else if(c_nlc)
        Bram[c_aeqb] <= B_update(c_err<$signed(9'd0), c_N[6], Bt);
    d_aeqb <= c_aeqb;
    d_N <= c_N;
    d_2BltN <= {Bt,1'b0} < c_N;
    d_errne0 <= c_err != $signed(9'd0);
    d_errgt0 <= c_err >  $signed(9'd0);
    if(c_err<$signed(9'd0))
        d_abserr <= $unsigned(-c_err);
    else
        d_abserr <= $unsigned( c_err);
end




always @ (posedge clk) begin
    automatic logic [11:0] At;
    automatic logic [ 3:0] k;
    automatic logic        map;
    automatic logic [ 9:0] merr;
    e_vl <= rst ? 1'b0 : d_vl;
    e_nlc <= rst ? 1'b0 : d_nlc;
    At = Aram[d_aeqb];
    k = get_k_r(d_N, At, d_aeqb);
    map = d_errne0 & (d_errgt0==((k==4'd0) & d_2BltN));
    merr = {d_abserr, 1'b0} - {9'd0,d_aeqb} - {9'd0,map};
    if(rst)
        Aram <= '{2{12'd4}};
    else if(d_nlc)
        Aram[d_aeqb] <= A_update(d_N[6], d_aeqb, merr, At);
    e_k <= k;
    e_merr <= merr[8:0];
end




always @ (posedge clk) begin
    automatic logic [9:0] merr_sk_e;
    f_vl <= rst ? 1'b0 : e_vl;
    f_nlc <= rst ? 1'b0 : e_nlc;
    f_k <= e_k;
    f_merr <= e_merr[8:0];
    merr_sk_e = (e_merr>>e_k);
    f_merr_sk <= merr_sk_e[8:0];
end





always @ (posedge clk) begin
    g_vl <= rst ? 1'b0 : f_vl;
    g_oc <= f_oc;
    g_pv <= f_pv;
    g_pc <= f_pc;
    if(~f_nlc) begin
        g_zc <= 5'd0;
        g_bv <= 9'd0;
        g_bc <= 4'd0;
    end else if(f_merr_sk < {4'd0,f_lm}) begin
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
    h_vl <= rst ? 1'b0 : g_vl;
    h_oc <= g_oc;
    h_pv <= g_pv;
    h_pc <= g_pc;
    h_zc <= g_zc;
    h_bv <= g_bv;
    h_bc <= g_bc;
end



always @ (posedge clk) begin
    j_vl <= rst ? 1'b0 : h_vl;
    j_oc <= h_oc;
    j_pv <= h_pv;
    j_pc <= h_pc;
    j_zc <= h_zc;
    j_bv <= h_bv;
    j_bc <= h_bc;
end



always @ (posedge clk) begin
    k_vl <= rst ? 1'b0 : j_vl;
    k_oc <= j_oc;
    k_pv <= j_pv;
    k_pc <= j_pc;
    k_zc <= j_zc;
    k_bv <= j_bv;
    k_bc <= j_bc;
end



always @ (posedge clk) begin
    o_vl <= rst ? 1'b0 : k_vl;
    o_oc <= k_oc;
    o_pv <= k_pv;
    o_pc <= k_pc;
    o_zc <= k_zc;
    o_bv <= k_bv;
    o_bc <= k_bc;
end



process_run process_run_i(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .i_vl         ( a_vl         ),
    .i_lc         ( a_lc         ),
    .i_rl         ( a_rl         ),
    .o_oc         ( f_oc         ),
    .o_pv         ( f_pv         ),
    .o_pc         ( f_pc         ),
    .o_lm         ( f_lm         )
);

endmodule













// 5 stage pipeline
module process_run(
    input wire         rst,
    input wire         clk,
    input wire         i_vl,
    input wire         i_lc,
    input wire [13:0]  i_rl,
    output reg [ 4:0]  o_oc,
    output reg [14:0]  o_pv,
    output reg [ 3:0]  o_pc,
    output reg [ 4:0]  o_lm
);

localparam [4:0] LIMIT = 5'd23;

wire [ 3:0] J_ROM [32];   assign J_ROM[0]= 4'd1;assign J_ROM[1]= 4'd1;assign J_ROM[2]= 4'd1;assign J_ROM[3]= 4'd1;assign J_ROM[4]= 4'd2;assign J_ROM[5]=  4'd2;assign J_ROM[6]=  4'd2;assign J_ROM[7]=  4'd2;assign J_ROM[8]=  4'd3;assign J_ROM[9]=  4'd3;assign J_ROM[10]=  4'd3;assign J_ROM[11]=  4'd3;assign J_ROM[12]=  4'd4;assign J_ROM[13]=  4'd4;assign J_ROM[14]=  4'd4;assign J_ROM[15]=  4'd4;assign J_ROM[16]=  4'd5;assign J_ROM[17]=  4'd5;assign J_ROM[18]=  4'd6;assign J_ROM[19]=   4'd6;assign J_ROM[20]=   4'd7;assign J_ROM[21]=   4'd7;assign J_ROM[22]=   4'd8;assign J_ROM[23]=   4'd8;assign J_ROM[24]=   4'd9;assign J_ROM[25]=  4'd10;assign J_ROM[26]=   4'd11;assign J_ROM[27]=   4'd12;assign J_ROM[28]=   4'd13;assign J_ROM[29]=   4'd14;assign J_ROM[30]=    4'd15;assign J_ROM[31]=    4'd15;
wire [15:0] L_ROM [32];   assign L_ROM[0]=16'd4;assign L_ROM[1]=16'd5;assign L_ROM[2]=16'd6;assign L_ROM[3]=16'd7;assign L_ROM[4]=16'd8;assign L_ROM[5]=16'd10;assign L_ROM[6]=16'd12;assign L_ROM[7]=16'd14;assign L_ROM[8]=16'd16;assign L_ROM[9]=16'd20;assign L_ROM[10]=16'd24;assign L_ROM[11]=16'd28;assign L_ROM[12]=16'd32;assign L_ROM[13]=16'd40;assign L_ROM[14]=16'd48;assign L_ROM[15]=16'd56;assign L_ROM[16]=16'd64;assign L_ROM[17]=16'd80;assign L_ROM[18]=16'd96;assign L_ROM[19]=16'd128;assign L_ROM[20]=16'd160;assign L_ROM[21]=16'd224;assign L_ROM[22]=16'd288;assign L_ROM[23]=16'd416;assign L_ROM[24]=16'd544;assign L_ROM[25]=16'd800;assign L_ROM[26]=16'd1312;assign L_ROM[27]=16'd2336;assign L_ROM[28]=16'd4384;assign L_ROM[29]=16'd8480;assign L_ROM[30]=16'd16672;assign L_ROM[31]=16'd33056;

reg [ 4:0]  idx;

reg [14:0]  a_pv;
reg [ 4:0]  a_idx;
reg [ 4:0]  a_nidx;
reg         a_lc;

reg [ 4:0]  b_oc;
reg [14:0]  b_pv;
reg [ 3:0]  b_pc;
reg         b_lc;

reg [ 4:0]  c_oc;
reg [14:0]  c_pv;
reg [ 3:0]  c_pc;
reg         c_lc;

reg [ 4:0]  d_oc;
reg [14:0]  d_pv;
reg [ 3:0]  d_pc;
reg         d_lc;

// ------------------------------------------------------------ stage1: calc next run_idx ------------------------------------------------------------
always @ (posedge clk) begin
    automatic logic [15:0] len;
    automatic logic [ 3:0] hsel;
    automatic logic [ 6:0] mask;
    automatic logic [ 2:0] hidx;
    automatic logic [ 4:0] nidx;
    len = {2'd0, i_rl} + L_ROM[idx];
    if(len<16'd64) begin
        mask = {4'h0, len[5], |len[5:4], |len[5:3] };
        hidx = {2'b0,mask[2]} + {2'b0,mask[1]} + {2'b0,mask[0]};
        nidx = {hidx, len[hidx+:2]};
        a_pv <= {12'd0, mask[2:0]&len[2:0] };
    end else if(len<16'd544) begin
        len  = len - 16'd32;
        hsel = len[7:4];
        mask = {4'h0, len[8], |len[8:7], |len[8:6]};
        hidx = {2'b0,mask[2]} + {2'b0,mask[1]} + {2'b0,mask[0]};
        nidx = {1'b1, hidx, hsel[hidx]};
        a_pv <= {8'd0, mask[2:0]&len[6:4], len[3:0] };
    end else begin
        len  = len - 16'd288;
        mask = {len[15], |len[15:14], |len[15:13], |len[15:12], |len[15:11], |len[15:10], |len[15:9] };
        hidx = {2'b0,mask[6]} + {2'b0,mask[5]} + {2'b0,mask[4]} + {2'b0,mask[3]} + {2'b0,mask[2]} + {2'b0,mask[1]} + {2'b0,mask[0]};
        nidx = {2'b11, hidx};
        a_pv <= {mask&len[14:8], len[7:0] };
    end
    a_idx <= idx;
    a_nidx <= nidx;
    a_lc <= i_lc;
    if(rst)
        idx <= 4'd0;
    else if(i_vl)
        idx <= (i_lc || nidx==4'd0) ? nidx : nidx-4'd1;
end
// ------------------------------------------------------------ end of stage1 ------------------------------------------------------------




// ------------------------------------------------------------ stage2: one_cnt(oc) and get J_ROM[run_idx] ------------------------------------------------------------
always @ (posedge clk) begin
    b_oc <= a_nidx - a_idx;
    b_pv <= a_pv;
    b_pc <= J_ROM[a_nidx];
    b_lc <= a_lc;
end
// ------------------------------------------------------------ end of stage2 ------------------------------------------------------------




// ------------------------------------------------------------ stage3:  ------------------------------------------------------------
always @ (posedge clk) begin
    c_oc <= b_oc;
    c_pv <= b_pv;
    c_pc <= b_pc;
    c_lc <= b_lc;
end
// ------------------------------------------------------------ end of stage3 ------------------------------------------------------------



always @ (posedge clk) begin
    d_oc <= c_oc;
    d_pv <= c_pv;
    d_pc <= c_pc;
    d_lc <= c_lc;
end


// ------------------------------------------------------------ stage5: modify pv and pc, and calc limit ------------------------------------------------------------
always @ (posedge clk) begin
    o_oc <= d_oc;
    if(~d_lc) begin
        o_pv <= d_pv;
        o_pc <= d_pc;
    end else if(d_pv>15'd0) begin
        o_pv <= 15'd1;
        o_pc <= 4'd1;
    end else begin
        o_pv <= 15'd0;
        o_pc <= 4'd0;
    end
    o_lm <= LIMIT - {1'b0,d_pc};
end

endmodule
