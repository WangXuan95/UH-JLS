
//--------------------------------------------------------------------------------------------------------
// Module  : uh_jls
// Type    : synthesizable, IP's top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: UH-JLS, a ultra high performance JPEG-LS image encoder
//--------------------------------------------------------------------------------------------------------

module uh_jls (
    input  wire        clk,                           // all below signals are sync with clk's posedge
    input  wire        i_sof,                         // start of image (should set to 1 for at least 50 cycles before inputting an image)
    input  wire [10:0] i_w,                           // image width = 5*(rrw+1) , i_w∈[0,2047], i.e., width=5,10,15...10240
    input  wire [15:0] i_h,                           // image height= rrh+1 , i_h∈[0,65535], i.e., height∈[1,65536]
    output wire        i_rdy,                         // input pixel ready, handshake with i_e
    input  wire        i_e,                           // input pixel enable, handshake with i_rdy
    input  wire [ 7:0] i_x0, i_x1, i_x2, i_x3, i_x4,  // input 5 neighbor pixels
    output wire        o_e,                           // output data enable
    output wire [63:0] o_data,                        // output data
    output wire        o_last                         // indicate the last output data of a image
);


reg [10:0] rrw;
reg [15:0] rrh;

always @ (posedge clk)
    if (i_sof) begin
        rrw <= i_w;
        rrh <= i_h;
    end


wire [15:0] img_w        = 16'd5 * ({5'd0,rrw} + 16'd1);
wire [15:0] img_h        = rrh + 16'd1;

wire [63:0] jls_header [0:3];
assign jls_header[0] = 64'hD8FF;
assign jls_header[1] = {img_h[7:0], img_h[15:8], 48'h080B00F7FF00};
assign jls_header[2] = {48'hDAFF00110101, img_w[7:0], img_w[15:8]};
assign jls_header[3] = 64'h01010800;


//---------------------------------------------------------------------------------------------------------------------------
// local parameters // BPP=8  NEAR=0  T1=3  T2=7  T3=21  ALPHA=256  QUANT=1  QBETA=256  QBPP=8  LIMIT=23  A_INIT=4
//---------------------------------------------------------------------------------------------------------------------------
localparam signed [ 8:0] P_T1 = 9'sd3;
localparam signed [ 8:0] P_T2 = 9'sd7;
localparam signed [ 8:0] P_T3 = 9'sd21;

//wire [3:0] J [32] = '{0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,5,5,6,6,7,7,8, 9,10,11,12,13,14,15};
//wire[13:0] J_MASK [32] = '{16383,16383,16383,16383,16382,16382,16382,16382,16380,16380,16380,16380,16376,16376,16376,16376,16368,16368,16352,16352,16320,16320,16256,16256,16128,15872,15360,14336,12288,8192,0,0};

wire [ 3:0] J_PLUS [0:31]; //= '{1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,6,6,7,7,8,8,9,10,11,12,13,14,15,15};
wire [13:0] J_MASK [0:31]; //= '{0,0,0,0,1,1,1,1,3,3,3,3,7,7,7,7,15,15,31,31,63,63,127,127,255,511,1023,2047,4095,8191,16383,16383};

assign J_PLUS[ 0] = 1;
assign J_PLUS[ 1] = 1;
assign J_PLUS[ 2] = 1;
assign J_PLUS[ 3] = 1;
assign J_PLUS[ 4] = 2;
assign J_PLUS[ 5] = 2;
assign J_PLUS[ 6] = 2;
assign J_PLUS[ 7] = 2;
assign J_PLUS[ 8] = 3;
assign J_PLUS[ 9] = 3;
assign J_PLUS[10] = 3;
assign J_PLUS[11] = 3;
assign J_PLUS[12] = 4;
assign J_PLUS[13] = 4;
assign J_PLUS[14] = 4;
assign J_PLUS[15] = 4;
assign J_PLUS[16] = 5;
assign J_PLUS[17] = 5;
assign J_PLUS[18] = 6;
assign J_PLUS[19] = 6;
assign J_PLUS[20] = 7;
assign J_PLUS[21] = 7;
assign J_PLUS[22] = 8;
assign J_PLUS[23] = 8;
assign J_PLUS[24] = 9;
assign J_PLUS[25] = 10;
assign J_PLUS[26] = 11;
assign J_PLUS[27] = 12;
assign J_PLUS[28] = 13;
assign J_PLUS[29] = 14;
assign J_PLUS[30] = 15;
assign J_PLUS[31] = 15;

assign J_MASK[ 0] = 0;
assign J_MASK[ 1] = 0;
assign J_MASK[ 2] = 0;
assign J_MASK[ 3] = 0;
assign J_MASK[ 4] = 1;
assign J_MASK[ 5] = 1;
assign J_MASK[ 6] = 1;
assign J_MASK[ 7] = 1;
assign J_MASK[ 8] = 3;
assign J_MASK[ 9] = 3;
assign J_MASK[10] = 3;
assign J_MASK[11] = 3;
assign J_MASK[12] = 7;
assign J_MASK[13] = 7;
assign J_MASK[14] = 7;
assign J_MASK[15] = 7;
assign J_MASK[16] = 15;
assign J_MASK[17] = 15;
assign J_MASK[18] = 31;
assign J_MASK[19] = 31;
assign J_MASK[20] = 63;
assign J_MASK[21] = 63;
assign J_MASK[22] = 127;
assign J_MASK[23] = 127;
assign J_MASK[24] = 255;
assign J_MASK[25] = 511;
assign J_MASK[26] = 1023;
assign J_MASK[27] = 2047;
assign J_MASK[28] = 4095;
assign J_MASK[29] = 8191;
assign J_MASK[30] = 16383;
assign J_MASK[31] = 16383;



//---------------------------------------------------------------------------------------------------------------------------
// function: predictor (get_px)
//---------------------------------------------------------------------------------------------------------------------------
function  [7:0] func_predictor;
    input [7:0] a, b, c;
begin
    if ( c>=a && c>=b )
        func_predictor = (a>b) ? b : a;
    else if ( c<=a && c<=b )
        func_predictor = (a>b) ? a : b;
    else
        func_predictor = a - c + b;
end
endfunction


//---------------------------------------------------------------------------------------------------------------------------
// function: q_quantize
//---------------------------------------------------------------------------------------------------------------------------
function signed [3:0] func_q_quantize;
    input       [7:0] x1, x2;
    reg signed  [8:0] delta;
begin
    delta = $signed({1'b0,x1}) - $signed({1'b0,x2});
    if      (delta <= -P_T3 )
        func_q_quantize = -4'sd4;
    else if (delta <= -P_T2 )
        func_q_quantize = -4'sd3;
    else if (delta <= -P_T1 )
        func_q_quantize = -4'sd2;
    else if (delta <  9'sd0 )
        func_q_quantize = -4'sd1;
    else if (delta == 9'sd0 )
        func_q_quantize =  4'sd0;
    else if (delta <   P_T1 )
        func_q_quantize =  4'sd1;
    else if (delta <   P_T2 )
        func_q_quantize =  4'sd2;
    else if (delta <   P_T3 )
        func_q_quantize =  4'sd3;
    else
        func_q_quantize =  4'sd4;
end
endfunction


//---------------------------------------------------------------------------------------------------------------------------
// function: get_q
//---------------------------------------------------------------------------------------------------------------------------
function  [9:0] func_get_q;
    input [7:0] a, b, c, d;
    reg signed [9:0] qs;
    reg              s;
    reg        [8:0] q;
begin
    qs = 10'sd81 * func_q_quantize(d,b) + 10'sd9 * func_q_quantize(b,c) + func_q_quantize(c,a);
    s = qs[9];
    q = s ? (~qs[8:0]+9'd1) : qs[8:0];
    q = q - 9'd1;
    func_get_q = {s, q};
end
endfunction



//---------------------------------------------------------------------------------------------------------------------------
// regs and wires
//---------------------------------------------------------------------------------------------------------------------------
// stage A
reg        a_e;
reg [ 7:0] a_x [0:4];
reg [10:0] a_ii;
reg [16:0] a_jj;

//-------------------------------------------------------------------------------------------------------------------
// linebuffer for context pixels
//-------------------------------------------------------------------------------------------------------------------
reg [39:0] linebuffer [0:2047];
reg        linebuffer_o_ack;
reg [39:0] linebuffer_o_raw_b;
wire[ 7:0] linebuffer_o_raw  [0:4];
reg [ 7:0] linebuffer_o_hold [0:4];
wire[ 7:0] linebuffer_o      [0:4];

always @ (posedge clk)
    linebuffer_o_ack <= i_rdy & (~i_sof);

always @ (posedge clk)
    linebuffer_o_raw_b <= linebuffer[a_ii];

assign linebuffer_o_raw[0] = linebuffer_o_raw_b[ 7: 0];
assign linebuffer_o_raw[1] = linebuffer_o_raw_b[15: 8];
assign linebuffer_o_raw[2] = linebuffer_o_raw_b[23:16];
assign linebuffer_o_raw[3] = linebuffer_o_raw_b[31:24];
assign linebuffer_o_raw[4] = linebuffer_o_raw_b[39:32];

always @ (posedge clk)
    if (linebuffer_o_ack) begin
        linebuffer_o_hold[0] <= linebuffer_o_raw[0];
        linebuffer_o_hold[1] <= linebuffer_o_raw[1];
        linebuffer_o_hold[2] <= linebuffer_o_raw[2];
        linebuffer_o_hold[3] <= linebuffer_o_raw[3];
        linebuffer_o_hold[4] <= linebuffer_o_raw[4];
    end

assign linebuffer_o[0] = linebuffer_o_ack ? linebuffer_o_raw[0] : linebuffer_o_hold[0];
assign linebuffer_o[1] = linebuffer_o_ack ? linebuffer_o_raw[1] : linebuffer_o_hold[1];
assign linebuffer_o[2] = linebuffer_o_ack ? linebuffer_o_raw[2] : linebuffer_o_hold[2];
assign linebuffer_o[3] = linebuffer_o_ack ? linebuffer_o_raw[3] : linebuffer_o_hold[3];
assign linebuffer_o[4] = linebuffer_o_ack ? linebuffer_o_raw[4] : linebuffer_o_hold[4];

// line buffer write
always @ (posedge clk)
    if (a_e & i_rdy)
        linebuffer[a_ii] <= {a_x[4], a_x[3], a_x[2], a_x[1], a_x[0]};

// stage B
reg        b_e;
reg        b_fc;
reg        b_lc;
reg        b_fr;
reg        b_eof;
reg [ 7:0] b_x [0:4];

// stage C
reg        c_e;
reg        c_fc;
reg        c_lc;
reg        c_fr;
reg        c_eof;
reg [ 7:0] c_xt [0:4];
reg [ 7:0] c_a;
reg [ 7:0] c_bt [0:4];
reg [ 7:0] c_ct;
reg [ 7:0] c_c;
wire[ 7:0] c_d = c_fr ? 8'd0 : (c_lc ? c_bt[4] : linebuffer_o[0]);
wire[ 7:0] c_b [-1:5]; //= '{c_c, c_bt[0], c_bt[1], c_bt[2], c_bt[3], c_bt[4], c_d};
wire[ 7:0] c_x [-1:4]; //= '{c_a, c_xt[0], c_xt[1], c_xt[2], c_xt[3], c_xt[4]};

assign c_b[-1] = c_c;
assign c_b[ 0] = c_bt[0];
assign c_b[ 1] = c_bt[1];
assign c_b[ 2] = c_bt[2];
assign c_b[ 3] = c_bt[3];
assign c_b[ 4] = c_bt[4];
assign c_b[ 5] = c_d;

assign c_x[-1] = c_a;
assign c_x[ 0] = c_xt[0];
assign c_x[ 1] = c_xt[1];
assign c_x[ 2] = c_xt[2];
assign c_x[ 3] = c_xt[3];
assign c_x[ 4] = c_xt[4];


// stage D
reg        d_e;
reg        d_lc;
reg        d_eof;
reg        d_runi;
reg        d_rune [0:4];
reg        d_rgar [0:4];
reg        d_rt   [0:4];
reg [ 7:0] d_x    [0:4];
reg [ 7:0] d_px   [0:4];
reg        d_s    [0:4];
reg [ 8:0] d_q    [0:4];

// stage E
reg        e_e;
reg        e_eof;
reg [ 7:0] e_x  [0:4];
reg [ 7:0] e_px [0:4];
reg        e_s  [0:4];
reg [ 4:0] e_q  [0:4];   // 
reg [ 3:0] e_g  [0:4];   // q group number
reg        e_on [0:4];
reg [13:0] e_rc;
reg [ 4:0] e_ri;
reg [13:0] e_cb [0:4];
reg [ 3:0] e_cn [0:4];

// stage F : double buffer
reg [ 3:0] f_i_ptr;
reg [ 1:0] f_o_ptr;

reg        f_eof;
wire       f_e = f_o_ptr != f_i_ptr[3:2];

assign     i_rdy = f_o_ptr != {~f_i_ptr[3], f_i_ptr[2]};  // double buffer input grant (not full)

reg [ 7:0] f_x  [0:7] [0:4];
reg [ 7:0] f_px [0:7] [0:4];
reg        f_s  [0:7] [0:4];
reg [ 4:0] f_q  [0:7] [0:4];
reg [ 3:0] f_g  [0:7] [0:4];
reg [13:0] f_cb [0:7] [0:4];
reg [ 3:0] f_cn [0:7] [0:4];
reg        f_on [0:7] [0:4];

// stage G
reg        g_e;
reg        g_eof;
reg [ 7:0] g_x  [0:19];
reg [ 7:0] g_px [0:19];
reg        g_s  [0:19];
reg [ 4:0] g_q  [0:19];
reg [ 3:0] g_g  [0:19];
reg [13:0] g_cb [0:19];
reg [ 3:0] g_cn [0:19];
reg        g_on [0:19];

// stage H
reg        h_e;
reg        h_eof;
reg [ 7:0] h_x  [0:19];
reg [ 7:0] h_px [0:19];
reg        h_s  [0:19];
reg [ 4:0] h_q  [0:19];
reg [ 3:0] h_g  [0:19];
reg [13:0] h_cb [0:19];
reg [ 3:0] h_cn [0:19];
reg        h_on [0:19];
reg [19:0] h_bitmap [0:19];

// stage J
reg        j_e;
reg        j_eof;
reg [ 7:0] j_x  [0:19];
reg [ 7:0] j_px [0:19];
reg        j_s  [0:19];
reg [ 4:0] j_q  [0:19];
reg [ 3:0] j_g  [0:19];
reg [13:0] j_cb [0:19];
reg [ 3:0] j_cn [0:19];
reg        j_on [0:19];
reg [ 4:0] j_nptr [0:19];

// stage K
reg        k_e;
reg        k_eof;
reg [ 7:0] k_x  [0:19];
reg [ 7:0] k_px [0:19];
reg        k_s  [0:19];
reg [ 4:0] k_q  [0:19];
reg [ 3:0] k_g  [0:19];
reg [13:0] k_cb [0:19];
reg [ 3:0] k_cn [0:19];
reg        k_on [0:19];
reg [ 4:0] k_nptr [0:19];
reg [ 4:0] k_nmax;
reg [ 4:0] k_ncnt;
wire       k_rdy;

// stage L
reg        l_eof;
reg        l_st;
reg        l_et;
reg [ 7:0] l_x  [0:19];
reg [ 7:0] l_px [0:19];
reg        l_s  [0:19];
reg [ 4:0] l_q  [0:19];
reg [ 3:0] l_g  [0:19];
reg [13:0] l_cb [0:19];
reg [ 3:0] l_cn [0:19];
reg        l_on [0:19];

// stage M
reg        m_eof;
reg        m_st;
reg        m_et;
reg [ 4:0] m_adr[0:13];
reg [ 3:0] m_g  [0:19];
reg [ 7:0] m_x  [0:19];
reg [ 7:0] m_px [0:19];
reg        m_s  [0:19];
reg [ 4:0] m_q  [0:19];
reg [13:0] m_cb;
reg [ 3:0] m_cn;
reg        m_on [0:19];

// stage N
reg        n_eof;
reg        n_st;
reg        n_et;
reg [ 3:0] n_g  [0:19];
reg        n_vl [0:13];
reg [ 7:0] n_x  [0:13];
reg [ 7:0] n_px [0:13];
reg        n_s  [0:13];
reg [ 4:0] n_q  [0:13];
reg [13:0] n_cb;
reg [ 3:0] n_cn;
reg        n_on [0:19];

// stage P : multiple stages (for bypassed signals that are not used in regular/run mode pipelines)
reg         p_eof[0:10];
reg         p_st [0:10];
reg         p_et [0:10];
reg  [ 3:0] p_g  [0:10] [0:19];
reg         p_on [0:10] [0:19];
reg  [13:0] p_cb [0:10];
reg  [ 3:0] p_cn [0:10];

// stage Q : regular/run mode pipelines output signals, and bypassed signals that are not used in regular/run mode pipelines
// bypassed signals that are not used in regular/run mode pipelines
wire        q_eof;
wire        q_st;
wire        q_et;
reg  [ 3:0] q_g   [0:19];     // not real register
reg         q_on  [0:19];     // not real register
wire [13:0] q_cb;
wire [ 3:0] q_cn;
wire        q_vl  [0:13];
wire [ 4:0] q_zc  [0:13];
wire [ 8:0] q_bv  [0:13];
wire [ 3:0] q_bc  [0:13];

// stage R : simple stage (re-ordered signals)
reg        r_eof;
reg        r_st;
reg        r_et;
reg        r_vl  [0:19];
reg [13:0] r_cb  [0:19];
reg [ 3:0] r_cn  [0:19];
reg [ 4:0] r_zc  [0:19];
reg [ 8:0] r_bv  [0:19];
reg [ 3:0] r_bc  [0:19];
reg        r_on  [0:19];

// stage S : simple stage (gathered signals)
reg        s_eof;
reg        s_et;
reg [13:0] s_cb  [0:19];
reg [ 4:0] s_zc  [0:19];
reg [ 8:0] s_bv  [0:19];
reg [ 3:0] s_bc  [0:19];

// stage T : double buffer
reg        t_eof;
reg [ 4:0] t_i_ptr;
reg [ 6:0] t_o_ptr;
wire       t_empty_n = t_i_ptr != t_o_ptr[6:2];

// stage U : simple stage (output bits and counts (raw))
reg        u_eof_n;
reg        u_eof;
reg        u_e;
reg [13:0] u_cb  [0:4];
reg [ 4:0] u_zc  [0:4]; // 0~24
reg [ 8:0] u_bv  [0:4];
reg [ 3:0] u_bc  [0:4]; // 0~13

// stage V : simple stage (output bits and counts (cutted bv))
reg        v_eof;
reg        v_e;
reg [13:0] v_cb  [0:4];
reg [ 4:0] v_zc  [0:4]; // 0~24
reg [ 8:0] v_bv  [0:4];
reg [ 3:0] v_bc  [0:4]; // 0~13

// stage W : simple stage (intra-channel merge)
reg        w_eof;
reg [36:0] w_bb  [0:4];
reg [ 5:0] w_bn  [0:4];

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


integer i, j;             // temporary loop variables


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage a: maintain counters: i, j
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if (i_sof) begin
        a_e <= 1'b0;
        for (i=0; i<5; i=i+1) a_x[i] <= 8'd0;
    end else if (i_rdy) begin
        a_e <= i_e;
        a_x[0] <= i_x0;
        a_x[1] <= i_x1;
        a_x[2] <= i_x2;
        a_x[3] <= i_x3;
        a_x[4] <= i_x4;
    end
    
always @ (posedge clk)
    if (i_sof) begin
        a_ii <= 0;
        a_jj <= 0;
    end else if (a_e & i_rdy) begin
        if (a_ii < rrw)
            a_ii <= a_ii + 11'd1;
        else begin
            a_ii <= 0;
            if (a_jj <= {1'b0,rrh})
                a_jj <= a_jj + 17'd1;
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage b: generate fc, lc, fr, eof
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if (i_sof) begin
        {b_e, b_fc, b_lc, b_fr, b_eof} <= 0;
        for (i=0; i<5; i=i+1) b_x[i] <= 8'd0;
    end else if (i_rdy) begin
        b_e <= a_e & (a_jj <= {1'b0,rrh});
        b_fc <= a_ii == 11'd0;
        b_lc <= a_ii == rrw;
        b_fr <= a_jj == 17'd0;
        b_eof <= a_jj > {1'b0,rrh};
        for (i=0; i<5; i=i+1) b_x[i] <= a_x[i];
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage c: generate context pixels
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if (i_sof) begin
        {c_e, c_fc, c_lc, c_fr, c_eof, c_a, c_ct, c_c} <= 0;
        for (i=0; i<5; i=i+1) begin
            c_xt[i] <= 0;
            c_bt[i] <= 0;
        end
    end else if (i_rdy) begin
        c_e <= b_e;
        c_fc <= b_fc;
        c_lc <= b_lc;
        c_fr <= b_fr;
        c_eof <= b_eof;
        if (b_e) begin
            for (i=0; i<5; i=i+1) begin
                c_xt[i] <= b_x[i];
                c_bt[i] <= b_fr ? 8'd0 : linebuffer_o[i];
            end
            c_a <= b_fc ? (b_fr ? 8'd0 : linebuffer_o[0]) : c_xt[4];
            if (b_fr) begin
                c_ct <= 8'd0;
                c_c  <= 8'd0;
            end else if (b_fc) begin
                c_ct <= linebuffer_o[0];
                c_c <= c_ct;
            end else
                c_c <= c_bt[4];
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage d: generate px, q
//-------------------------------------------------------------------------------------------------------------------
reg runi;

always @ (posedge clk)
    if (i_sof) begin
        {d_e, d_lc, d_eof, d_runi} <= 0;
        for (i=0; i<5; i=i+1) begin
            d_rune[i] <= 0;
            d_rgar[i] <= 0;
            d_rt[i] <= 0;
            d_x [i] <= 0;
            d_px[i] <= 0;
            d_s [i] <= 0;
            d_q [i] <= 0;
        end
    end else if (i_rdy) begin
        runi = ~c_fc & d_runi;
        d_e <= c_e;
        d_lc <= c_lc;
        d_eof <= c_eof;
        for (i=0; i<5; i=i+1) begin
            d_rune[i] <= 0;
            d_rt[i] <= 0;
            runi = runi | (c_x[i-1] == c_b[i-1] && c_b[i-1] == c_b[i] && c_b[i] == c_b[i+1]);
            d_x[i] <= c_x[i];
            d_px[i] <= func_predictor(c_x[i-1], c_b[i], c_b[i-1]);
            {d_s[i], d_q[i]} <= func_get_q(c_x[i-1], c_b[i], c_b[i-1], c_b[i+1]);
            if (runi) begin
                runi = c_x[i-1] == c_x[i];
                d_rune[i] <= ~runi;
                if (~runi) begin
                    d_rt[i] <= c_x[i-1] == c_b[i];
                    d_px[i] <= c_b[i];
                    d_s[i]  <= c_x[i-1] >  c_b[i];
                end
            end
            d_rgar[i] <= ~runi;
        end
        if (c_e)
            d_runi <= runi;
    end


//-------------------------------------------------------------------------------------------------------------------
// pipeline stage e: process run
//-------------------------------------------------------------------------------------------------------------------
reg [13:0] rc;                // not real register
reg [ 4:0] ri;                // not real register

always @ (posedge clk)
    if (i_sof) begin
        e_rc <= 0;
        e_ri <= 0;
        e_e <= 1'b0;
        e_eof <= 1'b0;
        for (i=0; i<5; i=i+1) begin
            e_x [i] <= 0;
            e_px[i] <= 0;
            e_s [i] <= 0;
            e_q [i] <= 0;
            e_g [i] <= 4'hF;
            e_cb[i] <= 0;
            e_cn[i] <= 0;
            e_on[i] <= 0;
        end
    end else if (i_rdy) begin
        e_e <= d_e;
        e_eof <= d_eof;
        for (i=0; i<5; i=i+1) begin
            e_x [i] <= d_x [i];
            e_px[i] <= d_px[i];
            e_s [i] <= d_s [i];
            e_on[i] <= 0;
        end
        if (d_e) begin
            rc = e_rc;
            ri = e_ri;
            for (i=0; i<5; i=i+1) begin
                e_cb[i] <= d_rune[i] ? rc : 14'd0;
                e_cn[i] <= d_rune[i] ? J_PLUS[ri] : 4'd0;
                if (d_rgar[i]) begin
                    rc = 0;
                    if (d_rune[i] && ri != 5'd0)
                        ri = ri - 5'd1;
                end else if (rc == J_MASK[ri]) begin
                    rc = 0;
                    ri = ri + 5'd1;
                    e_on[i] <= 1'b1;
                end else
                    rc = rc + 14'd1;
            end
            if (d_lc && rc != 14'd0)
                e_on[4] <= 1'b1;
            e_rc <= d_lc ? 14'd0 : rc;
            e_ri <= ri;
        end
        for (i=0; i<5; i=i+1) begin
            if (d_eof) begin
                e_q[i] <= 0;
                e_g[i] <= 4'hF;
            end else if (d_rune[i]) begin       // case: run mode (end of run)
                e_q[i] <= {4'd0, d_rt[i]};
                e_g[i] <= 4'd13;
            end else if (d_rgar[i]) begin       // case: regular mode
                e_q[i] <= d_q[i] / 9'd13;
                e_g[i] <= d_q[i] % 9'd13;
            end else begin                       // case: not run or regular
                e_q[i] <= 0;
                e_g[i] <= 4'hF;
            end
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// double buffer write
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if (i_sof) begin
        f_eof <= 1'b0;
        f_i_ptr <= 0;
    end else if (i_rdy) begin
        if (e_eof) begin
            if (f_i_ptr[1:0] != 2'd0)
                f_i_ptr <= f_i_ptr + 4'd1;
            else
                f_eof <= 1'b1;
        end else if (e_e) begin
            f_i_ptr <= f_i_ptr + 4'd1;
        end
        if (e_eof | e_e) begin
            for (i=0; i<5; i=i+1) begin
                f_x [f_i_ptr[2:0]][i] <= e_x[i];
                f_px[f_i_ptr[2:0]][i] <= e_px[i];
                f_s [f_i_ptr[2:0]][i] <= e_s[i];
                f_q [f_i_ptr[2:0]][i] <= e_q[i];
                f_g [f_i_ptr[2:0]][i] <= e_g[i];
                f_cb[f_i_ptr[2:0]][i] <= e_cb[i];
                f_cn[f_i_ptr[2:0]][i] <= e_cn[i];
                f_on[f_i_ptr[2:0]][i] <= e_on[i];
            end
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// double buffer read
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if (i_sof) begin
        g_e <= 1'b0;
        g_eof <= 1'b0;
        f_o_ptr <= 0;
        for (i=0; i<20; i=i+1) begin
            g_x [i] <= 0;
            g_px[i] <= 0;
            g_s [i] <= 0;
            g_q [i] <= 0;
            g_g [i] <= 4'hF;
            g_cb[i] <= 0;
            g_cn[i] <= 0;
            g_on[i] <= 0;
        end
    end else if (k_rdy) begin
        g_e   <= f_e;
        g_eof <= ~f_e & f_eof;
        if (~f_e) begin
            for (i=0; i<20; i=i+1) begin
                g_x [i] <= 0;
                g_px[i] <= 0;
                g_s [i] <= 0;
                g_q [i] <= 0;
                g_g [i] <= 4'hF;
                g_cb[i] <= 0;
                g_cn[i] <= 0;
                g_on[i] <= 0;
            end
        end else begin
            for (i=0; i<4; i=i+1) begin
                for (j=0; j<5; j=j+1) begin
                    g_x [i*5+j] <= f_x [{f_o_ptr[0],i[1:0]}] [j];
                    g_px[i*5+j] <= f_px[{f_o_ptr[0],i[1:0]}] [j];
                    g_s [i*5+j] <= f_s [{f_o_ptr[0],i[1:0]}] [j];
                    g_q [i*5+j] <= f_q [{f_o_ptr[0],i[1:0]}] [j];
                    g_g [i*5+j] <= f_g [{f_o_ptr[0],i[1:0]}] [j];
                    g_cb[i*5+j] <= f_cb[{f_o_ptr[0],i[1:0]}] [j];
                    g_cn[i*5+j] <= f_cn[{f_o_ptr[0],i[1:0]}] [j];
                    g_on[i*5+j] <= f_on[{f_o_ptr[0],i[1:0]}] [j];
                end
            end
            f_o_ptr <= f_o_ptr + 2'd1;
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// selecting circuit stage: calculate nptr
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if (i_sof) begin
        h_e   <= 1'b0;
        h_eof <= 1'b0;
        for (i=0; i<20; i=i+1) begin
            h_x [i] <= 0;
            h_px[i] <= 0;
            h_s [i] <= 0;
            h_q [i] <= 0;
            h_g [i] <= 4'hF;
            h_cb[i] <= 0;
            h_cn[i] <= 0;
            h_on[i] <= 0;
            h_bitmap[i] <= 0;
        end
    end else if (k_rdy) begin
        h_e  <= g_e;
        h_eof<= g_eof;
        for (i=0; i<20; i=i+1) begin
            h_x [i] <= g_x[i];
            h_px[i] <= g_px[i];
            h_s [i] <= g_s[i];
            h_q [i] <= g_q[i];
            h_g [i] <= g_g[i];
            h_cb[i] <= g_cb[i];
            h_cn[i] <= g_cn[i];
            h_on[i] <= g_on[i];
            for (j=0; j<20; j=j+1)
                h_bitmap[i][j] <= ((j<i) && (g_g[i] != 4'hF) && (g_g[i] == g_g[j])) ? 1'd1 : 1'd0;
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// selecting circuit stage: 
//-------------------------------------------------------------------------------------------------------------------
reg [4:0] nptr;          // not real register

always @ (posedge clk)
    if (i_sof) begin
        j_e   <= 1'b0;
        j_eof <= 1'b0;
        for (i=0; i<20; i=i+1) begin
            j_x [i] <= 0;
            j_px[i] <= 0;
            j_s [i] <= 0;
            j_q [i] <= 0;
            j_g [i] <= 4'hF;
            j_cb[i] <= 0;
            j_cn[i] <= 0;
            j_on[i] <= 0;
            j_nptr[i] <= 0;
        end
    end else if (k_rdy) begin
        j_e  <= h_e;
        j_eof<= h_eof;
        for (i=0; i<20; i=i+1) begin
            j_x [i] <= h_x[i];
            j_px[i] <= h_px[i];
            j_s [i] <= h_s[i];
            j_q [i] <= h_q[i];
            j_g [i] <= h_g[i];
            j_cb[i] <= h_cb[i];
            j_cn[i] <= h_cn[i];
            j_on[i] <= h_on[i];
            nptr = 5'd0;
            for(j=0; j<20; j=j+1)
                nptr = nptr + (h_bitmap[i][j] ? 5'd1 : 5'd0);
            j_nptr[i] <= nptr;
        end
    end


//-------------------------------------------------------------------------------------------------------------------
// selecting circuit stage: 
//-------------------------------------------------------------------------------------------------------------------
reg [4:0] nmax;           // not real register

always @ (posedge clk)
    if (i_sof) begin
        k_e   <= 1'b0;
        k_eof <= 1'b0;
        for (i=0; i<20; i=i+1) begin
            k_x [i] <= 0;
            k_px[i] <= 0;
            k_s [i] <= 0;
            k_q [i] <= 0;
            k_g [i] <= 4'hF;
            k_cb[i] <= 0;
            k_cn[i] <= 0;
            k_on[i] <= 0;
            k_nptr[i] <= 0;
        end
        k_nmax <= 0;
    end else if (k_rdy) begin
        k_e  <= j_e;
        k_eof<= j_eof;
        nmax = 5'd0;
        for (i=0; i<20; i=i+1) begin
            k_x [i] <= j_x[i];
            k_px[i] <= j_px[i];
            k_s [i] <= j_s[i];
            k_q [i] <= j_q[i];
            k_g [i] <= j_g[i];
            k_cb[i] <= j_cb[i];
            k_cn[i] <= j_cn[i];
            k_on[i] <= j_on[i];
            k_nptr[i] <= j_nptr[i];
            if (nmax < j_nptr[i])
                nmax = j_nptr[i];
        end
        k_nmax <= nmax;
    end

assign k_rdy = k_ncnt >= k_nmax;


always @ (posedge clk)                  // maintain double buffer output clock counter
    if (i_sof)
        k_ncnt <= 5'd0;
    else if (k_e)
        k_ncnt <= k_rdy ? 5'd0 : (k_ncnt + 5'd1);



//-------------------------------------------------------------------------------------------------------------------
// selecting circult output (buffered)
//-------------------------------------------------------------------------------------------------------------------
reg valid_group;                    // not real register

always @ (posedge clk) begin
    l_eof<= k_eof & (~i_sof);
    l_st <= k_e & (~i_sof) & (k_ncnt == 5'd0  );
    l_et <= k_e & (~i_sof) & (k_ncnt == k_nmax);
    for (i=0; i<20; i=i+1) begin
        l_x [i] <= k_x[i];
        l_px[i] <= k_px[i];
        l_s [i] <= k_s[i];
        l_q [i] <= k_q[i];
        l_on[i] <= i_sof ? 1'b0 : k_on[i];
        valid_group = k_e & (k_ncnt == k_nptr[i]) & (~i_sof);
        l_g [i] <=  valid_group ?  k_g[i] : 4'hF;
        l_cb[i] <= (valid_group && k_g[i] == 4'd13) ? k_cb[i] : 14'd0;
        l_cn[i] <= (valid_group && k_g[i] == 4'd13) ? k_cn[i] : 4'd0;
    end
end


//-------------------------------------------------------------------------------------------------------------------
// ordering circult (stage 1: decoders)
//-------------------------------------------------------------------------------------------------------------------
reg [13:0] cb;          // not real register
reg [ 3:0] cn;          // not real register

reg [ 3:0] gg4;         // not real register

always @ (*) begin
    cb = 0;
    cn = 0;
    for (i=0; i<20; i=i+1) begin
        cb = (cb | l_cb[i]);
        cn = (cn | l_cn[i]);
    end
end

always @ (posedge clk) begin
    m_eof<= l_eof & (~i_sof);
    m_st <= l_st & (~i_sof);
    m_et <= l_et & (~i_sof);
    m_cb <= cb;
    m_cn <= cn;
    for (i=0; i<20; i=i+1) begin
        m_g [i] <= l_g[i];
        m_x [i] <= l_x[i];
        m_px[i] <= l_px[i];
        m_s [i] <= l_s[i];
        m_q [i] <= l_q[i];
        m_on[i] <= i_sof ? 1'b0 : l_on[i];
    end
    for (gg4=4'd0; gg4<=4'd13; gg4=gg4+4'd1) begin     // generate 14 decoders
        m_adr[gg4] <= 5'h1F;
        for (i=19; i>=0; i=i-1)
            if (l_g[i] == gg4)
                m_adr[gg4] <= i[4:0];
    end
end


//-------------------------------------------------------------------------------------------------------------------
// ordering circult (stage 2: muxs)
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    n_eof<= m_eof & (~i_sof);
    n_st <= m_st  & (~i_sof);
    n_et <= m_et  & (~i_sof);
    for (i=0; i<=13; i=i+1) begin   // after adding run mode pipeline, modify to    (int i=0; i<=13; i++)
        if (m_adr[i] != 5'h1F) begin
            n_vl[i] <= 1'b1;
            n_x [i] <= m_x [m_adr[i]];
            n_px[i] <= m_px[m_adr[i]];
            n_s [i] <= m_s [m_adr[i]];
            n_q [i] <= m_q [m_adr[i]];
        end else begin
            n_vl[i] <= 1'b0;
            n_x [i] <= 0;
            n_px[i] <= 0;
            n_s [i] <= 0;
            n_q [i] <= 0;
        end
    end
    n_cb <= m_cb << (4'd14 - m_cn);
    n_cn <= m_cn;
    for (i=0; i<20; i=i+1) begin
        n_on[i] <= i_sof ? 1'b0 : m_on[i];
        n_g [i] <= m_g[i];
    end
end



//-------------------------------------------------------------------------------------------------------------------
// bypassed signals that are not used in regular/run mode pipelines
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    p_eof[0]<= n_eof & (~i_sof);
    p_st[0] <= n_st  & (~i_sof);
    p_et[0] <= n_et  & (~i_sof);
    for (i=0; i<20; i=i+1) begin
        p_g [0][i] <= n_g[i];
        p_on[0][i] <= i_sof ? 1'b0 : n_on[i];
    end
    p_cb[0] <= n_cb;
    p_cn[0] <= n_cn;
    for (j=0; j<10; j=j+1) begin
        p_eof[j+1] <= p_eof[j] & (~i_sof);
        p_st [j+1] <= p_st[j]  & (~i_sof);
        p_et [j+1] <= p_et[j]  & (~i_sof);
        for (i=0; i<20; i=i+1) begin
            p_g [j+1][i] <= p_g[j][i];
            p_on[j+1][i] <= i_sof ? 1'b0 : p_on[j][i];
        end
        p_cb[j+1] <= p_cb[j];
        p_cn[j+1] <= p_cn[j];
    end
end

assign q_eof= p_eof[10];
assign q_st = p_st[10];
assign q_et = p_et[10];
always @(*)
    for (i=0; i<20; i=i+1) begin
        q_g [i] = p_g [10][i];
        q_on[i] = p_on[10][i];
    end
assign q_cb = p_cb[10];
assign q_cn = p_cn[10];



//-------------------------------------------------------------------------------------------------------------------
// 13 regular mode pipelines
//-------------------------------------------------------------------------------------------------------------------
generate genvar g;
    for (g=0; g<13; g=g+1) begin : gen_regular_lanes
        regular u_regular (
            .rst         ( i_sof        ),
            .clk         ( clk          ),
            .i_vl        ( n_vl[g]      ),
            .i_x         ( n_x[g]       ),
            .i_px        ( n_px[g]      ),
            .i_s         ( n_s[g]       ),
            .i_qh        ( n_q[g]       ),
            .o_vl        ( q_vl[g]      ),
            .o_zc        ( q_zc[g]      ),
            .o_bv        ( q_bv[g]      ),
            .o_bc        ( q_bc[g]      )
        );
    end
endgenerate


//-------------------------------------------------------------------------------------------------------------------
// 1 run mode pipeline
//-------------------------------------------------------------------------------------------------------------------
run u_run (
    .rst         ( i_sof         ),
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
    r_eof<= q_eof & (~i_sof);
    r_st <= q_st  & (~i_sof);
    r_et <= q_et  & (~i_sof);
    for (i=0; i<20; i=i+1) begin
        if (i_sof)
            r_on[i] <= 0;
        else
            r_on[i] <= q_on[i];
        
        if ((q_g[i] <= 4'd13) && (~i_sof)) begin
            r_vl[i] <= q_vl[q_g[i]];
            r_cb[i] <= (q_g[i] == 4'd13) ? q_cb : 14'd0;
            r_cn[i] <= (q_g[i] == 4'd13) ? q_cn : 4'd0;
            r_zc[i] <= q_zc[q_g[i]];
            r_bv[i] <= q_bv[q_g[i]];
            r_bc[i] <= q_bc[q_g[i]];
        end else begin
            r_vl[i] <= 0;
            r_cb[i] <= 0;
            r_cn[i] <= 0;
            r_zc[i] <= 0;
            r_bv[i] <= 0;
            r_bc[i] <= 0;
        end
    end
end


//-------------------------------------------------------------------------------------------------------------------
// gather
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    s_eof<= r_eof & (~i_sof);
    s_et <= r_et  & (~i_sof);
    for (i=0; i<20; i=i+1) begin
        if (r_vl[i] && r_on[i]) $display("***assert error: r_vl & r_on");
        if (i_sof) begin
            s_cb[i] <= 0;
            s_zc[i] <= 0;
            s_bv[i] <= 0;
            s_bc[i] <= 0;
        end else if (r_on[i]) begin
            s_cb[i] <= 0;
            s_zc[i] <= 5'd1;
            s_bv[i] <= 0;
            s_bc[i] <= 0;
        end else if (r_vl[i]) begin
            s_cb[i] <= r_cb[i];
            s_zc[i] <= r_zc[i] + r_cn[i];
            s_bv[i] <= r_bv[i];
            s_bc[i] <= r_bc[i];
        end else if (r_st) begin
            s_cb[i] <= 0;
            s_zc[i] <= 0;
            s_bv[i] <= 0;
            s_bc[i] <= 0;
        end
    end
end


//-------------------------------------------------------------------------------------------------------------------
// double buffer (d2) write
//-------------------------------------------------------------------------------------------------------------------
wire t_full_n  = t_i_ptr != {~t_o_ptr[6], t_o_ptr[5:2]};

reg [13:0] t_cb  [0:319];
reg [ 4:0] t_zc  [0:319];
reg [ 8:0] t_bv  [0:319];
reg [ 3:0] t_bc  [0:319];

always @ (posedge clk)
    if (s_et) begin
        t_cb[20*t_i_ptr[3:0] +: 20] <= s_cb;
        t_zc[20*t_i_ptr[3:0] +: 20] <= s_zc;
        t_bv[20*t_i_ptr[3:0] +: 20] <= s_bv;
        t_bc[20*t_i_ptr[3:0] +: 20] <= s_bc;
    end

always @ (posedge clk)
    if (~i_sof) begin
        if (s_et) begin
            if (~t_full_n) $display("***assert error: double buffer (stage T) full");
            t_i_ptr <= t_i_ptr + 5'd1;
        end
        t_eof <= s_eof;
    end else begin
        t_i_ptr <= 0;
        t_eof <= 0;
    end


//-------------------------------------------------------------------------------------------------------------------
// double buffer (d2) read-out
//-------------------------------------------------------------------------------------------------------------------
always @ (posedge clk) begin
    u_e <= 1'b0;
    u_eof <= 1'b0;
    if (i_sof) begin
        t_o_ptr <= 0;
        u_eof_n <= 1'b1;
    end else if (t_empty_n) begin
        u_e <= 1'b1;
        
        u_cb <= t_cb[5*t_o_ptr[5:0]+:5];
        u_zc <= t_zc[5*t_o_ptr[5:0]+:5];
        u_bv <= t_bv[5*t_o_ptr[5:0]+:5];
        u_bc <= t_bc[5*t_o_ptr[5:0]+:5];
        
        t_o_ptr <= t_o_ptr + 7'd1;
    end else if (t_eof) begin
        u_eof_n <= 1'b0;
        u_eof<= ~u_eof_n;
        u_e  <=  u_eof_n;
        for (i=0; i<5; i=i+1) begin
            u_cb[i] <= 0;
            u_zc[i] <= 0;
            u_bv[i] <= 0;
            u_bc[i] <= 4'd13;
        end
    end
end


always @ (posedge clk) begin
    v_eof<= u_eof & (~i_sof);
    v_e  <= u_e   & (~i_sof);
    for (i=0; i<5; i=i+1) begin
        v_cb[i] <= u_cb[i];
        v_zc[i] <= u_zc[i];
        v_bv[i] <= u_bv[i] & (~(9'h1ff << u_bc[i]));
        v_bc[i] <= u_bc[i];
    end
end


always @ (posedge clk) begin
    w_eof <= v_eof & (~i_sof);
    if ((~v_e) | i_sof) begin
        for (i=0; i<5; i=i+1) begin
            w_bb[i] <= 0;
            w_bn[i] <= 0;
        end
    end else begin
        for (i=0; i<5; i=i+1) begin
            w_bb[i] <= {v_cb[i], 23'h0} | ( 37'd1 << (6'd37-v_zc[i]) ) | ( {28'd0, v_bv[i]} << (6'd37-v_zc[i]-v_bc[i]) ) ;
            w_bn[i] <= {1'b0, v_zc[i]} + {2'b0, v_bc[i]};
        end
    end
end


always @ (posedge clk)
    if (i_sof) begin
        x_eof <= 0;
        x_bb <= 0;
        x_bn <= 0;
    end else begin
        x_eof <= w_eof;
        x_bb <= ( {w_bb[0], 148'd0}                                                                          ) | 
                ( {w_bb[1], 148'd0} >>         w_bn[0]                                                       ) |
                ( {w_bb[2], 148'd0} >> ( {1'b0,w_bn[0]} + {1'b0,w_bn[1]}                                   ) ) |
                ( {w_bb[3], 148'd0} >> ( {1'b0,w_bn[0]} + {1'b0,w_bn[1]} + {1'b0,w_bn[2]}                  ) ) |
                ( {w_bb[4], 148'd0} >> ( {2'b0,w_bn[0]} + {2'b0,w_bn[1]} + {2'b0,w_bn[2]} + {2'b0,w_bn[3]} ) ) ;
        x_bn <= {2'b0,w_bn[0]} + {2'b0,w_bn[1]} + {2'b0,w_bn[2]} + {2'b0,w_bn[3]} + {2'b0,w_bn[4]} ;
    end


reg [407:0] bbuf;         // not real register
reg [  8:0] bcnt;         // not real register

always @ (posedge clk) begin
    {y_e, y_data} <= 0;
    if (i_sof) begin
        {y_bbuf, y_bcnt, y_eof} <= 0;
    end else begin
        bbuf = y_bbuf | ({x_bb,223'h0} >> y_bcnt);
        bcnt = y_bcnt + {1'd0,x_bn};
        if (bcnt >= 9'd64) begin
            y_e <= 1'b1;
            for (i=0; i<8; i=i+1) begin
                y_data[i*8+:8] <= bbuf[407:400];
                if (bbuf[407:400] == 8'hFF) begin
                    bbuf = {1'h0, bbuf[399:0], 7'h0};
                    bcnt = bcnt - 9'd7;
                end else begin
                    bbuf = {      bbuf[399:0], 8'h0};
                    bcnt = bcnt - 9'd8;
                end
            end
            //y_data <= bbuf[407:344];
            //bbuf = {bbuf[343:0], 64'h0};
            //bcnt -= 9'd64;
        end
        y_bbuf <= bbuf;
        y_bcnt <= bcnt;
        y_eof <= x_eof;
    end
end


always @ (posedge clk) begin
    {z_e, z_data, z_last} <= 0;
    if (i_sof) begin
        z_sof_idx <= 0;
        z_eof_n <= 1'b1;
    end else begin
        if (z_sof_idx < 3'd4) begin
            z_e <= 1'b1;
            z_data <= jls_header[z_sof_idx[1:0]];
            z_sof_idx <= z_sof_idx + 3'd1;
        end else if (y_e) begin
            z_e <= 1'b1;
            z_data <= y_data;
        end else if (y_eof) begin
            if (z_eof_n) begin
                z_e <= 1'b1;
                z_data <= 64'hD9FF;
                z_last <= 1'b1;
            end
            z_eof_n <= 1'b0;
        end
    end
end


assign o_e    = z_e;
assign o_data = z_data;
assign o_last = z_last;

endmodule
