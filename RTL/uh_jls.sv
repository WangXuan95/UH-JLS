`timescale 1ns/1ns

module uh_jls(
    input  wire        clk,     // all below signals are sync with clk's posedge
    input  wire        rstn,    // sync-reset (should hold at 0 for at least 30 cycles before inputting an image)
    input  wire [10:0] i_w,     // image width = 5*(i_w+1) , i_w∈[0,2047], i.e., width=5,10,15...10240
    input  wire [15:0] i_h,     // image height= i_h+1 , i_h∈[0,65535], i.e., height∈[1,65536]
    output wire        i_rdy,   // input pixel ready, handshake with i_e
    input  wire        i_e,     // input pixel enable, handshake with i_rdy
    input  wire [ 7:0] i_x [5], // input 5 neighbor pixels
    output wire        o_e,     // output data enable
    output wire [63:0] o_data,  // output data
    output wire        o_last   // indicate the last output data of a image
);

wire[15:0] img_w = 16'd5 * ({5'd0,i_w} + 16'd1);
wire[15:0] img_h = i_h + 16'd1;
wire[63:0] jls_header_1 = {img_h[7:0], img_h[15:8], 48'h080B00F7FF00};
wire[63:0] jls_header_2 = {48'hDAFF00110101, img_w[7:0], img_w[15:8]};
wire[63:0] jls_header [4] = '{64'hD8FF, jls_header_1, jls_header_2, 64'h01010800};


//---------------------------------------------------------------------------------------------------------------------------
// local parameters // BPP=8  NEAR=0  T1=3  T2=7  T3=21  ALPHA=256  QUANT=1  QBETA=256  QBPP=8  LIMIT=23  A_INIT=4
//---------------------------------------------------------------------------------------------------------------------------
localparam logic signed [ 8:0] P_T1 = 9'sd3;
localparam logic signed [ 8:0] P_T2 = 9'sd7;
localparam logic signed [ 8:0] P_T3 = 9'sd21;
//wire [3:0] J [32] = '{0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,5,5,6,6,7,7,8, 9,10,11,12,13,14,15};
wire[ 3:0] J_PLUS [32] = '{1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,6,6,7,7,8,8,9,10,11,12,13,14,15,15};
wire[13:0] J_MASK [32] = '{0,0,0,0,1,1,1,1,3,3,3,3,7,7,7,7,15,15,31,31,63,63,127,127,255,511,1023,2047,4095,8191,16383,16383};
//wire[13:0] J_MASK [32] = '{16383,16383,16383,16383,16382,16382,16382,16382,16380,16380,16380,16380,16376,16376,16376,16376,16368,16368,16352,16352,16320,16320,16256,16256,16128,15872,15360,14336,12288,8192,0,0};


//---------------------------------------------------------------------------------------------------------------------------
// function: predictor (get_px)
//---------------------------------------------------------------------------------------------------------------------------
function automatic logic [7:0] func_predictor(input [7:0] a, input [7:0] b, input [7:0] c);
    if( c>=a && c>=b )
        return a>b ? b : a;
    else if( c<=a && c<=b )
        return a>b ? a : b;
    else
        return a - c + b;
endfunction


//---------------------------------------------------------------------------------------------------------------------------
// function: q_quantize
//---------------------------------------------------------------------------------------------------------------------------
function automatic logic signed [3:0] func_q_quantize(input [7:0] x1, input [7:0] x2);
    logic signed [8:0] delta = $signed({1'b0,x1}) - $signed({1'b0,x2});
    if     (delta <= -P_T3 )
        return -$signed(4'd4);
    else if(delta <= -P_T2 )
        return -$signed(4'd3);
    else if(delta <= -P_T1 )
        return -$signed(4'd2);
    else if(delta <  $signed(9'd0) )
        return -$signed(4'd1);
    else if(delta == $signed(9'd0) )
        return  $signed(4'd0);
    else if(delta <   P_T1 )
        return  $signed(4'd1);
    else if(delta <   P_T2 )
        return  $signed(4'd2);
    else if(delta <   P_T3 )
        return  $signed(4'd3);
    else
        return  $signed(4'd4);
endfunction


//---------------------------------------------------------------------------------------------------------------------------
// function: get_q
//---------------------------------------------------------------------------------------------------------------------------
function automatic logic [9:0] func_get_q(input [7:0] a, input [7:0] b, input [7:0] c, input [7:0] d);
    logic signed [9:0] qs;
    logic              s;
    logic        [8:0] q;
    qs = $signed(10'd81) * func_q_quantize(d,b) + $signed(10'd9) * func_q_quantize(b,c) + func_q_quantize(c,a);
    s = qs[9];
    q = s ? (~qs[8:0]+9'd1) : qs[8:0];
    q -= 9'd1;
    return {s, q};
endfunction



//---------------------------------------------------------------------------------------------------------------------------
// regs and wires
//---------------------------------------------------------------------------------------------------------------------------
// stage A
reg        a_e;
reg [ 7:0] a_x [5];
reg [10:0] a_ii;
reg [16:0] a_jj;

//-------------------------------------------------------------------------------------------------------------------
// linebuffer for context pixels
//-------------------------------------------------------------------------------------------------------------------
reg [39:0] linebuffer [2048];
reg        linebuffer_o_ack;
reg [39:0] linebuffer_o_raw_b;
wire[ 7:0] linebuffer_o_raw  [5];
reg [ 7:0] linebuffer_o_hold [5];
wire[ 7:0] linebuffer_o      [5];

always @ (posedge clk)
    linebuffer_o_ack <= i_rdy & rstn;

always @ (posedge clk)
    linebuffer_o_raw_b <= linebuffer[a_ii];

assign linebuffer_o_raw[0] = linebuffer_o_raw_b[ 7: 0];
assign linebuffer_o_raw[1] = linebuffer_o_raw_b[15: 8];
assign linebuffer_o_raw[2] = linebuffer_o_raw_b[23:16];
assign linebuffer_o_raw[3] = linebuffer_o_raw_b[31:24];
assign linebuffer_o_raw[4] = linebuffer_o_raw_b[39:32];

always @ (posedge clk)
    if(linebuffer_o_ack)
        linebuffer_o_hold <= linebuffer_o_raw;

assign linebuffer_o = linebuffer_o_ack ? linebuffer_o_raw : linebuffer_o_hold;

// line buffer write
always @ (posedge clk)
    if(a_e & i_rdy) linebuffer[a_ii] <= {a_x[4], a_x[3], a_x[2], a_x[1], a_x[0]};

// stage B
reg        b_e;
reg        b_fc;
reg        b_lc;
reg        b_fr;
reg        b_eof;
reg [ 7:0] b_x [5];

// stage C
reg        c_e;
reg        c_fc;
reg        c_lc;
reg        c_fr;
reg        c_eof;
reg [ 7:0] c_xt [5];
reg [ 7:0] c_a;
reg [ 7:0] c_bt [5];
reg [ 7:0] c_ct;
reg [ 7:0] c_c;
wire[ 7:0] c_d = c_fr ? '0 : (c_lc ? c_bt[4] : linebuffer_o[0]);
wire[ 7:0] c_b [-1:5] = '{c_c, c_bt[0], c_bt[1], c_bt[2], c_bt[3], c_bt[4], c_d};
wire[ 7:0] c_x [-1:4] = '{c_a, c_xt[0], c_xt[1], c_xt[2], c_xt[3], c_xt[4]};

// stage D
reg        d_e;
reg        d_lc;
reg        d_eof;
reg        d_runi;
reg        d_rune [5];
reg        d_rgar [5];
reg        d_rt [5];
reg [ 7:0] d_x  [5];
reg [ 7:0] d_px [5];
reg        d_s  [5];
reg [ 8:0] d_q  [5];

// stage E
reg        e_e;
reg        e_eof;
reg [ 7:0] e_x  [5];
reg [ 7:0] e_px [5];
reg        e_s  [5];
reg [ 4:0] e_q  [5];   // 
reg [ 3:0] e_g  [5];   // q group number
reg        e_on [5];
reg [13:0] e_rc;
reg [ 4:0] e_ri;
reg [13:0] e_cb [5];
reg [ 3:0] e_cn [5];

// stage F : double buffer
reg [ 3:0] f_i_ptr;
reg [ 1:0] f_o_ptr;

reg        f_eof;
wire       f_e = f_o_ptr != f_i_ptr[3:2];

assign     i_rdy = f_o_ptr != {~f_i_ptr[3], f_i_ptr[2]};  // double buffer input grant (not full)

reg [ 7:0] f_x  [8] [5];
reg [ 7:0] f_px [8] [5];
reg        f_s  [8] [5];
reg [ 4:0] f_q  [8] [5];
reg [ 3:0] f_g  [8] [5];
reg [13:0] f_cb [8] [5];
reg [ 3:0] f_cn [8] [5];
reg        f_on [8] [5];

// stage G H J K
reg        g_e;
reg        g_eof;
reg [ 7:0] g_x  [20];
reg [ 7:0] g_px [20];
reg        g_s  [20];
reg [ 4:0] g_q  [20];
reg [ 3:0] g_g  [20];
reg [13:0] g_cb [20];
reg [ 3:0] g_cn [20];
reg        g_on [20];

reg        h_e;
reg        h_eof;
reg [ 7:0] h_x  [20];
reg [ 7:0] h_px [20];
reg        h_s  [20];
reg [ 4:0] h_q  [20];
reg [ 3:0] h_g  [20];
reg [13:0] h_cb [20];
reg [ 3:0] h_cn [20];
reg        h_on [20];
reg [19:0] h_bitmap [20];

reg        j_e;
reg        j_eof;
reg [ 7:0] j_x  [20];
reg [ 7:0] j_px [20];
reg        j_s  [20];
reg [ 4:0] j_q  [20];
reg [ 3:0] j_g  [20];
reg [13:0] j_cb [20];
reg [ 3:0] j_cn [20];
reg        j_on [20];
reg [ 4:0] j_nptr [20];

reg        k_e;
reg        k_eof;
reg [ 7:0] k_x  [20];
reg [ 7:0] k_px [20];
reg        k_s  [20];
reg [ 4:0] k_q  [20];
reg [ 3:0] k_g  [20];
reg [13:0] k_cb [20];
reg [ 3:0] k_cn [20];
reg        k_on [20];
reg [ 4:0] k_nptr [20];
reg [ 4:0] k_nmax;
reg [ 4:0] k_ncnt;
wire       k_rdy;

// stage L
reg        l_eof;
reg        l_st;
reg        l_et;
reg [ 7:0] l_x  [20];
reg [ 7:0] l_px [20];
reg        l_s  [20];
reg [ 4:0] l_q  [20];
reg [ 3:0] l_g  [20];
reg [13:0] l_cb [20];
reg [ 3:0] l_cn [20];
reg        l_on [20];

// stage M
reg        m_eof;
reg        m_st;
reg        m_et;
reg [ 4:0] m_adr[14];
reg [ 3:0] m_g  [20];
reg [ 7:0] m_x  [20];
reg [ 7:0] m_px [20];
reg        m_s  [20];
reg [ 4:0] m_q  [20];
reg [13:0] m_cb;
reg [ 3:0] m_cn;
reg        m_on [20];

// stage N
reg        n_eof;
reg        n_st;
reg        n_et;
reg [ 3:0] n_g  [20];
reg        n_vl [14];
reg [ 7:0] n_x  [14];
reg [ 7:0] n_px [14];
reg        n_s  [14];
reg [ 4:0] n_q  [14];
reg [13:0] n_cb;
reg [ 3:0] n_cn;
reg        n_on [20];

// stage P : multiple stages (for bypassed signals that are not used in regular/run mode pipelines)
reg         p_eof[11];
reg         p_st [11];
reg         p_et [11];
reg  [ 3:0] p_g  [11] [20];
reg         p_on [11] [20];
reg  [13:0] p_cb [11];
reg  [ 3:0] p_cn [11];

// stage Q : regular/run mode pipelines output signals, and bypassed signals that are not used in regular/run mode pipelines
// bypassed signals that are not used in regular/run mode pipelines
wire        q_eof;
wire        q_st;
wire        q_et;
wire [ 3:0] q_g   [20];
wire        q_on  [20];
wire [13:0] q_cb;
wire [ 3:0] q_cn;
wire        q_vl  [14];
wire [ 4:0] q_zc  [14];
wire [ 8:0] q_bv  [14];
wire [ 3:0] q_bc  [14];

// stage R : simple stage (re-ordered signals)
reg        r_eof;
reg        r_st;
reg        r_et;
reg        r_vl  [20];
reg [13:0] r_cb  [20];
reg [ 3:0] r_cn  [20];
reg [ 4:0] r_zc  [20];
reg [ 8:0] r_bv  [20];
reg [ 3:0] r_bc  [20];
reg        r_on  [20];

// stage S : simple stage (gathered signals)
reg        s_eof;
reg        s_et;
reg [13:0] s_cb  [20];
reg [ 4:0] s_zc  [20];
reg [ 8:0] s_bv  [20];
reg [ 3:0] s_bc  [20];

// stage T : double buffer
reg        t_eof;
reg [ 4:0] t_i_ptr;
reg [ 6:0] t_o_ptr;
wire       t_empty_n = t_i_ptr != t_o_ptr[6:2];
reg [13:0] t_cb  [320];
reg [ 4:0] t_zc  [320];
reg [ 8:0] t_bv  [320];
reg [ 3:0] t_bc  [320];

// stage U : simple stage (output bits and counts (raw))
reg        u_eof_n;
reg        u_eof;
reg        u_e;
reg [13:0] u_cb  [5];
reg [ 4:0] u_zc  [5]; // 0~24
reg [ 8:0] u_bv  [5];
reg [ 3:0] u_bc  [5]; // 0~13

// stage V : simple stage (output bits and counts (cutted bv))
reg        v_eof;
reg        v_e;
reg [13:0] v_cb  [5];
reg [ 4:0] v_zc  [5]; // 0~24
reg [ 8:0] v_bv  [5];
reg [ 3:0] v_bc  [5]; // 0~13

// stage W : simple stage (intra-channel merge)
reg        w_eof;
reg [36:0] w_bb  [5];
reg [ 5:0] w_bn  [5];

// stage X : simple stage (inter-channel merge)
reg        x_eof;
reg[184:0] x_bb;
reg[  7:0] x_bn;

// stage Y : simple stage
reg        y_eof;
reg[407:0] y_bbuf;
reg [ 8:0] y_bcnt;
reg        y_e;
reg [63:0] y_data;

// stage Z : simple stage (added .jls header)
reg [ 2:0] z_sof_idx;
reg        z_eof_n;
reg        z_e;
reg [63:0] z_data;
reg        z_last;


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage a: maintain counters: ii, jj
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(i_rdy) begin
            a_e <= i_e;
            a_x <= i_x;
        end
    end else begin
        a_e <= '0;
        a_x <= '{5{'0}};
    end
    
always @ (posedge clk)
    if(rstn) begin
        if(a_e & i_rdy) begin
            if(a_ii < i_w)
                a_ii <= a_ii + 11'd1;
            else begin
                a_ii <= '0;
                if(a_jj <= {1'b0,i_h})
                    a_jj <= a_jj + 17'd1;
            end
        end
    end else begin
        a_ii <= '0;
        a_jj <= '0;
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage b: generate fc, lc, fr, eof
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(i_rdy) begin
            b_e <= a_e & (a_jj <= {1'b0,i_h});
            b_fc <= a_ii == '0;
            b_lc <= a_ii == i_w;
            b_fr <= a_jj == '0;
            b_eof <= a_jj > {1'b0,i_h};
            b_x <= a_x;
        end
    end else begin
        {b_e, b_fc, b_lc, b_fr, b_eof} <= '0;
        b_x <= '{5{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage c: generate context pixels
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(i_rdy) begin
            c_e <= b_e;
            c_fc <= b_fc;
            c_lc <= b_lc;
            c_fr <= b_fr;
            c_eof <= b_eof;
            if(b_e) begin
                c_xt <= b_x;
                if(b_fr)
                    c_bt <= '{5{'0}};
                else
                    c_bt <= linebuffer_o;
                c_a <= b_fc ? (b_fr ? '0 : linebuffer_o[0]) : c_xt[4];
                if(b_fr) begin
                    c_ct <= '0;
                    c_c <= '0;
                end else if(b_fc) begin
                    c_ct <= linebuffer_o[0];
                    c_c <= c_ct;
                end else
                    c_c <= c_bt[4];
            end
        end
    end else begin
        {c_e, c_fc, c_lc, c_fr, c_eof, c_a, c_ct, c_c} <= '0;
        c_xt <= '{5{'0}};
        c_bt <= '{5{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage d: generate px, q
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(i_rdy) begin
            automatic logic runi = ~c_fc & d_runi;
            d_e <= c_e;
            d_lc <= c_lc;
            d_eof <= c_eof;
            d_rune <= '{5{'0}};
            d_rt <= '{5{'0}};
            for(int ii=0; ii<5; ii++) begin
                runi |= c_x[ii-1] == c_b[ii-1] && c_b[ii-1] == c_b[ii] && c_b[ii] == c_b[ii+1];
                d_x[ii] <= c_x[ii];
                d_px[ii] <= func_predictor(c_x[ii-1], c_b[ii], c_b[ii-1]);
                {d_s[ii], d_q[ii]} <= func_get_q(c_x[ii-1], c_b[ii], c_b[ii-1], c_b[ii+1]);
                if(runi) begin
                    runi = c_x[ii-1] == c_x[ii];
                    d_rune[ii] <= ~runi;
                    if(~runi) begin
                        d_rt[ii] <= c_x[ii-1] == c_b[ii];
                        d_px[ii] <= c_b[ii];
                        d_s[ii]  <= c_x[ii-1] >  c_b[ii];
                    end
                end
                d_rgar[ii] <= ~runi;
            end
            if(c_e)
                d_runi <= runi;
        end
    end else begin
        {d_e, d_lc, d_eof, d_runi} <= '0;
        d_rune <= '{5{'0}};
        d_rgar <= '{5{'0}};
        d_rt <= '{5{'0}};
        d_x  <= '{5{'0}};
        d_px <= '{5{'0}};
        d_s  <= '{5{'0}};
        d_q  <= '{5{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage e: process run
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(i_rdy) begin
            e_e <= d_e;
            e_eof <= d_eof;
            e_x <= d_x;
            e_px <= d_px;
            e_s <= d_s;
            e_on <= '{5{'0}};
            if(d_e) begin
                automatic logic [13:0] rc = e_rc;
                automatic logic [ 4:0] ri = e_ri;
                for(int ii=0; ii<5; ii++) begin
                    e_cb[ii] <= d_rune[ii] ? rc : '0;
                    e_cn[ii] <= d_rune[ii] ? J_PLUS[ri] : '0;
                    if(d_rgar[ii]) begin
                        rc = '0;
                        if(d_rune[ii] && ri != '0)
                            ri --;
                    end else if(rc == J_MASK[ri]) begin
                        rc = '0;
                        ri ++;
                        e_on[ii] <= 1'b1;
                    end else
                        rc ++;
                end
                if(d_lc && rc != '0)
                    e_on[4] <= 1'b1;
                e_rc <= d_lc ? '0 : rc;
                e_ri <= ri;
            end
            for(int ii=0; ii<5; ii++) begin
                if(d_eof) begin
                    e_q[ii] <= '0;
                    e_g[ii] <= '1;
                end else if(d_rune[ii]) begin       // case: run mode (end of run)
                    e_q[ii] <= {4'd0, d_rt[ii]};
                    e_g[ii] <= 4'd13;
                end else if(d_rgar[ii]) begin       // case: regular mode
                    e_q[ii] <= d_q[ii] / 9'd13;
                    e_g[ii] <= d_q[ii] % 9'd13;
                end else begin                      // case: not run or regular
                    e_q[ii] <= '0;
                    e_g[ii] <= '1;
                end
            end
        end
    end else begin
        e_rc <= '0;
        e_ri <= '0;
        e_e <= 1'b0;
        e_eof <= 1'b0;
        e_x  <= '{5{'0}};
        e_px <= '{5{'0}};
        e_s  <= '{5{'0}};
        e_q <= '{5{'0}};
        e_g <= '{5{'1}};
        e_cb <= '{5{'0}};
        e_cn <= '{5{'0}};
        e_on <= '{5{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// double buffer write
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(i_rdy) begin
            if(e_eof) begin
                if(f_i_ptr[1:0] != '0)
                    f_i_ptr <= f_i_ptr + 4'd1;
                else
                    f_eof <= 1'b1;
            end else if(e_e) begin
                f_i_ptr <= f_i_ptr + 4'd1;
            end
            if(e_eof | e_e) begin
                f_x [f_i_ptr[2:0]] <= e_x;
                f_px[f_i_ptr[2:0]] <= e_px;
                f_s [f_i_ptr[2:0]] <= e_s;
                f_q [f_i_ptr[2:0]] <= e_q;
                f_g [f_i_ptr[2:0]] <= e_g;
                f_cb[f_i_ptr[2:0]] <= e_cb;
                f_cn[f_i_ptr[2:0]] <= e_cn;
                f_on[f_i_ptr[2:0]] <= e_on;
            end
        end
    end else begin
        f_eof <= 1'b0;
        f_i_ptr <= '0;
    end


//-------------------------------------------------------------------------------------------------------------------
// double buffer read
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(k_rdy) begin
            g_e   <= f_e;
            g_eof <= ~f_e & f_eof;
            if(f_e) begin
                for(int ii=0; ii<4; ii++) begin
                    g_x [ii*5+:5] <= f_x [{f_o_ptr[0],ii[1:0]}];
                    g_px[ii*5+:5] <= f_px[{f_o_ptr[0],ii[1:0]}];
                    g_s [ii*5+:5] <= f_s [{f_o_ptr[0],ii[1:0]}];
                    g_q [ii*5+:5] <= f_q [{f_o_ptr[0],ii[1:0]}];
                    g_g [ii*5+:5] <= f_g [{f_o_ptr[0],ii[1:0]}];
                    g_cb[ii*5+:5] <= f_cb[{f_o_ptr[0],ii[1:0]}];
                    g_cn[ii*5+:5] <= f_cn[{f_o_ptr[0],ii[1:0]}];
                    g_on[ii*5+:5] <= f_on[{f_o_ptr[0],ii[1:0]}];
                end
                f_o_ptr <= f_o_ptr + 2'd1;
            end else begin
                g_x  <= '{20{'0}};
                g_px <= '{20{'0}};
                g_s  <= '{20{'0}};
                g_q  <= '{20{'0}};
                g_g  <= '{20{'1}};
                g_cb <= '{20{'0}};
                g_cn <= '{20{'0}};
                g_on <= '{20{'0}};
            end
        end
    end else begin
        g_e <= 1'b0;
        g_eof <= 1'b0;
        f_o_ptr <= '0;
        g_x  <= '{20{'0}};
        g_px <= '{20{'0}};
        g_s  <= '{20{'0}};
        g_q  <= '{20{'0}};
        g_g  <= '{20{'1}};
        g_cb <= '{20{'0}};
        g_cn <= '{20{'0}};
        g_on <= '{20{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// selecting circuit stage: calculate nptr
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(k_rdy) begin
            h_e  <= g_e;
            h_eof<= g_eof;
            h_x  <= g_x;
            h_px <= g_px;
            h_s  <= g_s;
            h_q  <= g_q;
            h_g  <= g_g;
            h_cb <= g_cb;
            h_cn <= g_cn;
            h_on <= g_on;
            for(int ii=0; ii<20; ii++)
                for(int jj=0; jj<20; jj++)
                    h_bitmap[ii][jj] <= (jj<ii && g_g[ii] != '1 && g_g[ii] == g_g[jj]) ? 1'd1 : 1'd0;
        end
    end else begin
        h_e   <= 1'b0;
        h_eof <= 1'b0;
        h_x  <= '{20{'0}};
        h_px <= '{20{'0}};
        h_s  <= '{20{'0}};
        h_q  <= '{20{'0}};
        h_g  <= '{20{'1}};
        h_cb <= '{20{'0}};
        h_cn <= '{20{'0}};
        h_on <= '{20{'0}};
        h_bitmap <= '{20{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// selecting circuit stage: 
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(k_rdy) begin
            j_e  <= h_e;
            j_eof<= h_eof;
            j_x  <= h_x;
            j_px <= h_px;
            j_s  <= h_s;
            j_q  <= h_q;
            j_g  <= h_g;
            j_cb <= h_cb;
            j_cn <= h_cn;
            j_on <= h_on;
            for(int ii=0; ii<20; ii++) begin
                automatic logic [4:0] nptr = '0;
                for(int jj=0; jj<20; jj++)
                    nptr += h_bitmap[ii][jj] ? 5'd1 : 5'd0;
                j_nptr[ii] <= nptr;
            end
        end
    end else begin
        j_e   <= 1'b0;
        j_eof <= 1'b0;
        j_x  <= '{20{'0}};
        j_px <= '{20{'0}};
        j_s  <= '{20{'0}};
        j_q  <= '{20{'0}};
        j_g  <= '{20{'1}};
        j_cb <= '{20{'0}};
        j_cn <= '{20{'0}};
        j_on <= '{20{'0}};
        j_nptr <= '{20{'0}};
    end


//-------------------------------------------------------------------------------------------------------------------
// selecting circuit stage: 
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(k_rdy) begin
            automatic logic [4:0] nmax = '0;
            k_e  <= j_e;
            k_eof<= j_eof;
            k_x  <= j_x;
            k_px <= j_px;
            k_s  <= j_s;
            k_q  <= j_q;
            k_g  <= j_g;
            k_cb <= j_cb;
            k_cn <= j_cn;
            k_on <= j_on;
            k_nptr <= j_nptr;
            for(int ii=0; ii<20; ii++)
                if(nmax < j_nptr[ii])
                    nmax = j_nptr[ii];
            k_nmax <= nmax;
        end
    end else begin
        k_e   <= 1'b0;
        k_eof <= 1'b0;
        k_x  <= '{20{'0}};
        k_px <= '{20{'0}};
        k_s  <= '{20{'0}};
        k_q  <= '{20{'0}};
        k_g  <= '{20{'1}};
        k_cb <= '{20{'0}};
        k_cn <= '{20{'0}};
        k_on <= '{20{'0}};
        k_nptr <= '{20{'0}};
        k_nmax <= '0;
    end


assign k_rdy = k_ncnt >= k_nmax;


//-------------------------------------------------------------------------------------------------------------------
// maintain double buffer output clock counter
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rstn) begin
        if(k_e)
            k_ncnt <= k_rdy ? '0 : k_ncnt + 5'd1;
    end else
        k_ncnt <= '0;



//-------------------------------------------------------------------------------------------------------------------
// selecting circult output (buffered)
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    l_eof<= k_eof & rstn;
    l_st <= k_e & rstn & (k_ncnt == '0    );
    l_et <= k_e & rstn & (k_ncnt == k_nmax);
    l_x  <= k_x;
    l_px <= k_px;
    l_s  <= k_s;
    l_q  <= k_q;
    if(rstn)
        l_on <= k_on;
    else
        l_on <= '{20{'0}};
    for(int ii=0; ii<20; ii++) begin
        automatic logic valid_group = k_e & k_ncnt == k_nptr[ii] & rstn;
        l_g[ii]  <=  valid_group ?  k_g[ii] : '1;
        l_cb[ii] <= (valid_group && k_g[ii] == 4'd13) ? k_cb[ii] : '0;
        l_cn[ii] <= (valid_group && k_g[ii] == 4'd13) ? k_cn[ii] : '0;
    end
end


//-------------------------------------------------------------------------------------------------------------------
// ordering circult (stage 1: decoders)
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    automatic logic [13:0] cb = '0;
    automatic logic [ 4:0] cn = '0;
    for(int ii=0; ii<20; ii++) begin
        cb |= l_cb[ii];
        cn |= l_cn[ii];
    end
    m_eof<= l_eof & rstn;
    m_st <= l_st & rstn;
    m_et <= l_et & rstn;
    m_g  <= l_g;
    m_x  <= l_x;
    m_px <= l_px;
    m_s  <= l_s;
    m_q  <= l_q;
    m_cb <= cb;
    m_cn <= cn;
    if(rstn)
        m_on <= l_on;
    else
        m_on <= '{20{'0}};
    for(logic [3:0] gg=4'd0; gg<=4'd13; gg++) begin  // generate 14 decoders
        m_adr[gg] <= '1;
        for(int ii=19; ii>=0; ii--)
            if(l_g[ii] == gg)
                m_adr[gg] <= ii[4:0];
    end
end


//-------------------------------------------------------------------------------------------------------------------
// ordering circult (stage 2: muxs)
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    n_eof<= m_eof & rstn;
    n_st <= m_st & rstn;
    n_et <= m_et & rstn;
    for(int gg=0; gg<=13; gg++) begin   // after adding run mode pipeline, modify to    (int gg=0; gg<=13; gg++)
        if(m_adr[gg] != '1) begin
            n_vl[gg] <= 1'b1;
            n_x [gg] <= m_x [m_adr[gg]];
            n_px[gg] <= m_px[m_adr[gg]];
            n_s [gg] <= m_s [m_adr[gg]];
            n_q [gg] <= m_q [m_adr[gg]];
        end else begin
            n_vl[gg] <= 1'b0;
            n_x [gg] <= '0;
            n_px[gg] <= '0;
            n_s [gg] <= '0;
            n_q [gg] <= '0;
        end
    end
    n_cb <= m_cb << (4'd14 - m_cn);
    n_cn <= m_cn;
    if(rstn)
        n_on <= m_on;
    else
        n_on <= '{20{'0}};
    n_g <= m_g;
end


//-------------------------------------------------------------------------------------------------------------------
// bypassed signals that are not used in regular/run mode pipelines
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    p_eof[0]<= n_eof & rstn;
    p_st[0] <= n_st & rstn;
    p_et[0] <= n_et & rstn;
    p_g [0] <= n_g;
    if(rstn)
        p_on[0] <= n_on;
    else
        p_on[0] <= '{20{'0}};
    p_cb[0] <= n_cb;
    p_cn[0] <= n_cn;
    for(int ss=0; ss<10; ss++) begin
        p_eof[ss+1]<= p_eof[ss] & rstn;
        p_st[ss+1] <= p_st[ss] & rstn;
        p_et[ss+1] <= p_et[ss] & rstn;
        p_g [ss+1] <= p_g [ss];
        if(rstn)
            p_on[ss+1] <= p_on[ss];
        else
            p_on[ss+1] <= '{20{'0}};
        p_cb[ss+1] <= p_cb[ss];
        p_cn[ss+1] <= p_cn[ss];
    end
end
assign q_eof= p_eof[10];
assign q_st = p_st[10];
assign q_et = p_et[10];
assign q_g  = p_g [10];
assign q_on = p_on[10];
assign q_cb = p_cb[10];
assign q_cn = p_cn[10];


//-------------------------------------------------------------------------------------------------------------------
// 13 regular mode pipelines
//-------------------------------------------------------------------------------------------------------------------
generate genvar gg; for(gg=0; gg<13; gg++) begin : gen_regular_lanes
regular regular_lane(
    .rstn        ( rstn          ),
    .clk         ( clk           ),
    .i_vl        ( n_vl[gg]      ),
    .i_x         ( n_x[gg]       ),
    .i_px        ( n_px[gg]      ),
    .i_s         ( n_s[gg]       ),
    .i_qh        ( n_q[gg]       ),
    .o_vl        ( q_vl[gg]      ),
    .o_zc        ( q_zc[gg]      ),
    .o_bv        ( q_bv[gg]      ),
    .o_bc        ( q_bc[gg]      )
);
end endgenerate


//-------------------------------------------------------------------------------------------------------------------
// 1 run mode pipeline
//-------------------------------------------------------------------------------------------------------------------
run run_lane(
    .rstn        ( rstn          ),
    .clk         ( clk           ),
    .i_vl        ( n_vl[13]      ),
    .i_x         ( n_x[13]       ),
    .i_px        ( n_px[13]      ),
    .i_s         ( n_s[13]       ),
    .i_q         ( n_q[13][0]    ),
    .i_cn        ( n_cn          ),
    .o_vl        ( q_vl[13]      ),
    .o_zc        ( q_zc[13]      ),
    .o_bv        ( q_bv[13]      ),
    .o_bc        ( q_bc[13]      )
);


//-------------------------------------------------------------------------------------------------------------------
// re-order
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    r_eof<= q_eof & rstn;
    r_st <= q_st & rstn;
    r_et <= q_et & rstn;
    if(rstn)
        r_on <= q_on;
    else
        r_on <= '{20{'0}};
    for(int ii=0; ii<20; ii++) begin
        if(q_g[ii] <= 4'd13 && rstn) begin
            r_vl[ii] <= q_vl[q_g[ii]];
            r_cb[ii] <= q_g[ii] == 4'd13 ? q_cb : '0;
            r_cn[ii] <= q_g[ii] == 4'd13 ? q_cn : '0;
            r_zc[ii] <= q_zc[q_g[ii]];
            r_bv[ii] <= q_bv[q_g[ii]];
            r_bc[ii] <= q_bc[q_g[ii]];
        end else begin
            r_vl[ii] <= '0;
            r_cb[ii] <= '0;
            r_cn[ii] <= '0;
            r_zc[ii] <= '0;
            r_bv[ii] <= '0;
            r_bc[ii] <= '0;
        end
    end
end


//-------------------------------------------------------------------------------------------------------------------
// gather
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    s_eof<= r_eof & rstn;
    s_et <= r_et & rstn;
    for(int ii=0; ii<20; ii++) begin
        if(r_vl[ii] && r_on[ii]) $display("***assert error: r_vl & r_on");
        if(~rstn) begin
            s_cb[ii] <= '0;
            s_zc[ii] <= '0;
            s_bv[ii] <= '0;
            s_bc[ii] <= '0;
        end else if(r_on[ii]) begin
            s_cb[ii] <= '0;
            s_zc[ii] <= 5'd1;
            s_bv[ii] <= '0;
            s_bc[ii] <= '0;
        end else if(r_vl[ii]) begin
            s_cb[ii] <= r_cb[ii];
            s_zc[ii] <= r_zc[ii] + r_cn[ii];
            s_bv[ii] <= r_bv[ii];
            s_bc[ii] <= r_bc[ii];
        end else if(r_st) begin
            s_cb[ii] <= '0;
            s_zc[ii] <= '0;
            s_bv[ii] <= '0;
            s_bc[ii] <= '0;
        end
    end
end


//-------------------------------------------------------------------------------------------------------------------
// double buffer (d2) write
//-------------------------------------------------------------------------------------------------------------------
wire t_full_n  = t_i_ptr != {~t_o_ptr[6], t_o_ptr[5:2]};
always @ (posedge clk)
    if(rstn) begin
        if(s_et) begin
            if(~t_full_n) $display("***assert error: double buffer (stage T) full");
            t_i_ptr <= t_i_ptr + 5'd1;
            t_cb[20*t_i_ptr[3:0]+:20] <= s_cb;
            t_zc[20*t_i_ptr[3:0]+:20] <= s_zc;
            t_bv[20*t_i_ptr[3:0]+:20] <= s_bv;
            t_bc[20*t_i_ptr[3:0]+:20] <= s_bc;
        end
        t_eof <= s_eof;
    end else begin
        t_i_ptr <= '0;
        t_eof <= '0;
    end


//-------------------------------------------------------------------------------------------------------------------
// double buffer (d2) read-out
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    u_e <= 1'b0;
    u_eof <= 1'b0;
    if(rstn) begin
        if(t_empty_n) begin
            u_e <= 1'b1;
            u_cb <= t_cb[5*t_o_ptr[5:0]+:5];
            u_zc <= t_zc[5*t_o_ptr[5:0]+:5];
            u_bv <= t_bv[5*t_o_ptr[5:0]+:5];
            u_bc <= t_bc[5*t_o_ptr[5:0]+:5];
            t_o_ptr <= t_o_ptr + 7'd1;
        end else if(t_eof) begin
            u_eof_n <= 1'b0;
            u_eof<= ~u_eof_n;
            u_e  <=  u_eof_n;
            u_cb <= '{5{'0}};
            u_zc <= '{5{'0}};
            u_bv <= '{5{'0}};
            u_bc <= '{5{4'd13}};
        end
    end else begin
        t_o_ptr <= '0;
        u_eof_n <= 1'b1;
    end
end


always @ (posedge clk) begin
    v_eof<= u_eof & rstn;
    v_e  <= u_e & rstn;
    v_cb <= u_cb;
    v_zc <= u_zc;
    for(int ii=0; ii<5; ii++)
        v_bv[ii] <= u_bv[ii] & ~ (9'h1ff << u_bc[ii]);
    v_bc <= u_bc;
end


always @ (posedge clk) begin
    w_eof <= v_eof & rstn;
    if(v_e & rstn) begin
        for(int ii=0; ii<5; ii++) begin
            w_bb[ii] <= {v_cb[ii], 23'h0} | ( 37'd1 << (6'd37-v_zc[ii]) ) | ( {28'd0, v_bv[ii]} << (6'd37-v_zc[ii]-v_bc[ii]) ) ;
            w_bn[ii] <= {1'b0, v_zc[ii]} + {2'b0, v_bc[ii]};
        end
    end else begin
        w_bb <= '{5{'0}};
        w_bn <= '{5{'0}};
    end
end


always @ (posedge clk)
    if(rstn) begin
        x_eof <= w_eof;
        x_bb <= ( {w_bb[0], 148'd0}                                                                          ) | 
                ( {w_bb[1], 148'd0} >>         w_bn[0]                                                       ) |
                ( {w_bb[2], 148'd0} >> ( {1'b0,w_bn[0]} + {1'b0,w_bn[1]}                                   ) ) |
                ( {w_bb[3], 148'd0} >> ( {1'b0,w_bn[0]} + {1'b0,w_bn[1]} + {1'b0,w_bn[2]}                  ) ) |
                ( {w_bb[4], 148'd0} >> ( {2'b0,w_bn[0]} + {2'b0,w_bn[1]} + {2'b0,w_bn[2]} + {2'b0,w_bn[3]} ) ) ;
        x_bn <= {2'b0,w_bn[0]} + {2'b0,w_bn[1]} + {2'b0,w_bn[2]} + {2'b0,w_bn[3]} + {2'b0,w_bn[4]} ;
    end else begin
        x_eof <= '0;
        x_bb <= '0;
        x_bn <= '0;
    end


always @ (posedge clk) begin
    {y_e, y_data} <= '0;
    if(rstn) begin
        automatic logic [407:0] bbuf = y_bbuf | ({x_bb,223'h0} >> y_bcnt);
        automatic logic [  8:0] bcnt = y_bcnt + {1'd0,x_bn};
        if(bcnt >= 9'd64) begin
            y_e <= 1'b1;
            for(int pp=0; pp<8; pp++) begin
                y_data[pp*8+:8] <= bbuf[407:400];
                if(bbuf[407:400] == '1) begin
                    bbuf = {1'h0, bbuf[399:0], 7'h0};
                    bcnt -= 9'd7;
                end else begin
                    bbuf = {      bbuf[399:0], 8'h0};
                    bcnt -= 9'd8;
                end
            end
            //y_data <= bbuf[407:344];
            //bbuf = {bbuf[343:0], 64'h0};
            //bcnt -= 9'd64;
        end
        y_bbuf <= bbuf;
        y_bcnt <= bcnt;
        y_eof <= x_eof;
    end else begin
        {y_bbuf, y_bcnt, y_eof} <= '0;
    end
end


always @ (posedge clk) begin
    {z_e, z_data, z_last} <= '0;
    if(rstn) begin
        if(z_sof_idx < 3'd4) begin
            z_e <= 1'b1;
            z_data <= jls_header[z_sof_idx[1:0]];
            z_sof_idx <= z_sof_idx + 3'd1;
        end else if(y_e) begin
            z_e <= 1'b1;
            z_data <= y_data;
        end else if(y_eof) begin
            if(z_eof_n) begin
                z_e <= 1'b1;
                z_data <= 64'hD9FF;
                z_last <= 1'b1;
            end
            z_eof_n <= 1'b0;
        end
    end else begin
        z_sof_idx <= '0;
        z_eof_n <= 1'b1;
    end
end


assign o_e    = z_e;
assign o_data = z_data;
assign o_last = z_last;

endmodule
