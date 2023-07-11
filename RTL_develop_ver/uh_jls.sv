`timescale 1 ns/1 ns

module uh_jls(
    input  wire        rst,
    input  wire        clk,
    // image size
    input  wire [ 9:0] width,
    input  wire [15:0] height,
    // input interface (raw pixels)
    input  wire        ena,
    output wire        stall_n,
    input  wire [ 7:0] i_x    [1:8],
    // output interface (JLS stream)
    output reg         o_vl,
    output reg [191:0] o_bv,
    output reg  [ 7:0] o_bc
);

wire [7:0] i_b    [1:8];

wire       a_sl;
wire       a_sp;
wire       a_ep;
wire       a_vl;
wire [7:0] a_b    [1:10];
wire [7:0] a_x    [1:8];

wire       b_sl;
wire       b_sp;
wire       b_vl;
wire [1:0] b_st   [1:8];
wire [7:0] b_b    [1:9];
wire [7:0] b_x    [1:8];

wire       c_sp;
wire       c_vl;
wire [1:0] c_st   [1:8];
wire [7:0] c_b    [0:9];
wire [7:0] c_x    [0:8];

wire       d_sp;
wire       d_vl;
wire [7:0] d_b    [0:8];
wire [7:0] d_x    [0:8];
wire       d_s    [1:8];
wire [4:0] d_qh   [1:8];
wire [3:0] d_ql   [1:8];
wire [2:0] d_qcnt [1:8];

wire        e_vl;
wire [ 7:0] e_x   [1:8];
wire [ 7:0] e_px  [1:8];
wire        e_s   [1:8];
wire [ 4:0] e_qh  [1:8];
wire [ 3:0] e_ql  [1:8];
wire [ 2:0] e_qcnt[1:8];
wire [ 2:0] e_qcnt_max;
wire [13:0] e_rl  [1:8];

wire        f_et;
wire [ 7:0] f_x   [1:8];
wire [ 7:0] f_px  [1:8];
wire        f_s   [1:8];
wire [ 4:0] f_qh  [1:8];
wire [ 3:0] f_ql  [1:8];
wire [13:0] f_rl;

wire        g_et;
wire        g_vl  [0:13];
wire [ 7:0] g_x   [0:13];
wire [ 7:0] g_px  [0:13];
wire        g_s   [0:13];
wire [ 4:0] g_qh  [0:13];
wire [ 3:0] g_ql  [1:8];
wire [13:0] g_rl;

wire        h_et;
wire [ 3:0] h_ql  [1:8];
wire        h_vl  [0:13];
wire [ 4:0] h_oc;
wire [14:0] h_pv;
wire [ 3:0] h_pc;
wire [ 4:0] h_zc  [0:13];
wire [ 8:0] h_bv  [0:13];
wire [ 3:0] h_bc  [0:13];

wire        j_et;
wire        j_vl  [1:8];
wire [ 4:0] j_oc  [1:8];
wire [14:0] j_pv  [1:8];
wire [ 3:0] j_pc  [1:8];
wire [ 4:0] j_zc  [1:8];
wire [ 8:0] j_bv  [1:8];
wire [ 3:0] j_bc  [1:8];

wire        k_vl  [1:8];
wire [ 4:0] k_oc  [1:8];
wire [14:0] k_pv  [1:8];
wire [ 3:0] k_pc  [1:8];
wire [ 4:0] k_zc  [1:8];
wire [ 8:0] k_bv  [1:8];
wire [ 3:0] k_bc  [1:8];

wire        l_vl  [1:8];
wire [62:0] l_bv  [1:8];
wire [ 5:0] l_bc  [1:8];

reg         m_vl;
wire[125:0] m_bv  [1:4];
wire [ 6:0] m_bc  [1:4];

reg         n_vl;
wire[191:0] n_bv  [1:2];
wire [ 7:0] n_bc  [1:2];

reg         p_vl;
wire[191:0] p_bv;
wire [ 7:0] p_bc;

shift_buffer #(
    .WLEVEL      ( 10            ),
    .DWIDTH      ( 8 * 8         )
) line_buffer_i (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .length      ( width-10'd22  ),
    .ivalid      ( ena & stall_n ),
    .idata       ( {d_x[1],d_x[2],d_x[3],d_x[4],d_x[5],d_x[6],d_x[7],d_x[8]} ),
    .odata       ( {i_b[1],i_b[2],i_b[3],i_b[4],i_b[5],i_b[6],i_b[7],i_b[8]} )
);

source source_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .width       ( width         ),
    .height      ( height        ),
    .ena         ( ena & stall_n ),
    .i_b         ( i_b           ),
    .i_x         ( i_x           ),
    .o_sl        ( a_sl          ),
    .o_sp        ( a_sp          ),
    .o_ep        ( a_ep          ),
    .o_vl        ( a_vl          ),
    .o_b         ( a_b           ),
    .o_x         ( a_x           )
);

runner runner_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .ena         ( ena & stall_n ),
    .i_sl        ( a_sl          ),
    .i_sp        ( a_sp          ),
    .i_ep        ( a_ep          ),
    .i_vl        ( a_vl          ),
    .i_b         ( a_b           ),
    .i_x         ( a_x           ),
    .o_sl        ( b_sl          ),
    .o_sp        ( b_sp          ),
    .o_vl        ( b_vl          ),
    .o_st        ( b_st          ),
    .o_b         ( b_b           ),
    .o_x         ( b_x           )
);

acgen acgen_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .ena         ( ena & stall_n ),
    .i_sl        ( b_sl          ),
    .i_sp        ( b_sp          ),
    .i_vl        ( b_vl          ),
    .i_st        ( b_st          ),
    .i_b         ( b_b           ),
    .i_x         ( b_x           ),
    .o_sp        ( c_sp          ),
    .o_vl        ( c_vl          ),
    .o_st        ( c_st          ),
    .o_b         ( c_b           ),
    .o_x         ( c_x           )
);

shuffler shuffler_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .ena         ( ena & stall_n ),
    .i_sp        ( c_sp          ),
    .i_vl        ( c_vl          ),
    .i_st        ( c_st          ),
    .i_b         ( c_b           ),
    .i_x         ( c_x           ),
    .o_sp        ( d_sp          ),
    .o_vl        ( d_vl          ),
    .o_b         ( d_b           ),
    .o_x         ( d_x           ),
    .o_s         ( d_s           ),
    .o_qh        ( d_qh          ),
    .o_ql        ( d_ql          ),
    .o_qcnt      ( d_qcnt        )
);

preprocess preprocess_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .ena         ( ena & stall_n ),
    .i_sp        ( d_sp          ),
    .i_vl        ( d_vl          ),
    .i_b         ( d_b           ),
    .i_x         ( d_x           ),
    .i_s         ( d_s           ),
    .i_qh        ( d_qh          ),
    .i_ql        ( d_ql          ),
    .i_qcnt      ( d_qcnt        ),
    .o_vl        ( e_vl          ),
    .o_x         ( e_x           ),
    .o_px        ( e_px          ),
    .o_s         ( e_s           ),
    .o_qh        ( e_qh          ),
    .o_ql        ( e_ql          ),
    .o_qcnt      ( e_qcnt        ),
    .o_qcnt_max  ( e_qcnt_max    ),
    .o_rl        ( e_rl          )
);

issue issue_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .stall_n     ( stall_n       ),
    .i_vl        ( e_vl          ),
    .i_x         ( e_x           ),
    .i_px        ( e_px          ),
    .i_s         ( e_s           ),
    .i_qh        ( e_qh          ),
    .i_ql        ( e_ql          ),
    .i_qcnt      ( e_qcnt        ),
    .i_qcnt_max  ( e_qcnt_max    ),
    .i_rl        ( e_rl          ),
    .o_et        ( f_et          ),
    .o_x         ( f_x           ),
    .o_px        ( f_px          ),
    .o_s         ( f_s           ),
    .o_qh        ( f_qh          ),
    .o_ql        ( f_ql          ),
    .o_rl        ( f_rl          )
);

sort sort_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_et        ( f_et          ),
    .i_x         ( f_x           ),
    .i_px        ( f_px          ),
    .i_s         ( f_s           ),
    .i_qh        ( f_qh          ),
    .i_ql        ( f_ql          ),
    .i_rl        ( f_rl          ),
    .o_et        ( g_et          ),
    .o_vl        ( g_vl          ),
    .o_x         ( g_x           ),
    .o_px        ( g_px          ),
    .o_s         ( g_s           ),
    .o_qh        ( g_qh          ),
    .o_ql        ( g_ql          ),
    .o_rl        ( g_rl          )
);

generate genvar jj; for(jj=0; jj<13; jj++) begin : gen_regular_lanes
regular regular_lane(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_vl        ( g_vl[jj]      ),
    .i_x         ( g_x[jj]       ),
    .i_px        ( g_px[jj]      ),
    .i_s         ( g_s[jj]       ),
    .i_qh        ( g_qh[jj]      ),
    .o_vl        ( h_vl[jj]      ),
    .o_zc        ( h_zc[jj]      ),
    .o_bv        ( h_bv[jj]      ),
    .o_bc        ( h_bc[jj]      )
);
end endgenerate

run run_lane(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_vl        ( g_vl[13]      ),
    .i_x         ( g_x[13]       ),
    .i_px        ( g_px[13]      ),
    .i_lc        ( g_qh[13][4]   ),
    .i_aeqb      ( g_qh[13][0]   ),
    .i_agtb      ( g_qh[13][1]   ),
    .i_rl        ( g_rl          ),
    .o_vl        ( h_vl[13]      ),
    .o_oc        ( h_oc          ),
    .o_pv        ( h_pv          ),
    .o_pc        ( h_pc          ),
    .o_zc        ( h_zc[13]      ),
    .o_bv        ( h_bv[13]      ),
    .o_bc        ( h_bc[13]      )
);

bypass bypass_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_et        ( g_et          ),
    .i_ql        ( g_ql          ),
    .o_et        ( h_et          ),
    .o_ql        ( h_ql          )
);

invsort invsort_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_et        ( h_et          ),
    .i_ql        ( h_ql          ),
    .i_vl        ( h_vl          ),
    .i_oc        ( h_oc          ),
    .i_pv        ( h_pv          ),
    .i_pc        ( h_pc          ),
    .i_zc        ( h_zc          ),
    .i_bv        ( h_bv          ),
    .i_bc        ( h_bc          ),
    .o_et        ( j_et          ),
    .o_vl        ( j_vl          ),
    .o_oc        ( j_oc          ),
    .o_pv        ( j_pv          ),
    .o_pc        ( j_pc          ),
    .o_zc        ( j_zc          ),
    .o_bv        ( j_bv          ),
    .o_bc        ( j_bc          )
);

merge merge_i(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_et        ( j_et          ),
    .i_vl        ( j_vl          ),
    .i_oc        ( j_oc          ),
    .i_pv        ( j_pv          ),
    .i_pc        ( j_pc          ),
    .i_zc        ( j_zc          ),
    .i_bv        ( j_bv          ),
    .i_bc        ( j_bc          ),
    .o_vl        ( k_vl          ),
    .o_oc        ( k_oc          ),
    .o_pv        ( k_pv          ),
    .o_pc        ( k_pc          ),
    .o_zc        ( k_zc          ),
    .o_bv        ( k_bv          ),
    .o_bc        ( k_bc          )
);

generate genvar ii; for(ii=1; ii<=8; ii++) begin : gen_ch_packers
channelpacker ch_packers(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .i_vl        ( k_vl[ii]      ),
    .i_oc        ( k_oc[ii]      ),
    .i_pv        ( k_pv[ii]      ),
    .i_pc        ( k_pc[ii]      ),
    .i_zc        ( k_zc[ii]      ),
    .i_bv        ( k_bv[ii]      ),
    .i_bc        ( k_bc[ii]      ),
    .o_vl        ( l_vl[ii]      ),
    .o_bv        ( l_bv[ii]      ),
    .o_bc        ( l_bc[ii]      )
);
end endgenerate

bitpacker1 bitpacker_11(
    .clk         ( clk           ),
    .i_bv_a      ( l_bv[1]       ),
    .i_bc_a      ( l_bc[1]       ),
    .i_bv_b      ( l_bv[2]       ),
    .i_bc_b      ( l_bc[2]       ),
    .o_bv        ( m_bv[1]       ),
    .o_bc        ( m_bc[1]       )
);

bitpacker1 bitpacker_12(
    .clk         ( clk           ),
    .i_bv_a      ( l_bv[3]       ),
    .i_bc_a      ( l_bc[3]       ),
    .i_bv_b      ( l_bv[4]       ),
    .i_bc_b      ( l_bc[4]       ),
    .o_bv        ( m_bv[2]       ),
    .o_bc        ( m_bc[2]       )
);

bitpacker1 bitpacker_13(
    .clk         ( clk           ),
    .i_bv_a      ( l_bv[5]       ),
    .i_bc_a      ( l_bc[5]       ),
    .i_bv_b      ( l_bv[6]       ),
    .i_bc_b      ( l_bc[6]       ),
    .o_bv        ( m_bv[3]       ),
    .o_bc        ( m_bc[3]       )
);

bitpacker1 bitpacker_14(
    .clk         ( clk           ),
    .i_bv_a      ( l_bv[7]       ),
    .i_bc_a      ( l_bc[7]       ),
    .i_bv_b      ( l_bv[8]       ),
    .i_bc_b      ( l_bc[8]       ),
    .o_bv        ( m_bv[4]       ),
    .o_bc        ( m_bc[4]       )
);

bitpacker2 bitpacker_21(
    .clk         ( clk           ),
    .i_bv_a      ( m_bv[1]       ),
    .i_bc_a      ( m_bc[1]       ),
    .i_bv_b      ( m_bv[2]       ),
    .i_bc_b      ( m_bc[2]       ),
    .o_bv        ( n_bv[1]       ),
    .o_bc        ( n_bc[1]       )
);

bitpacker2 bitpacker_22(
    .clk         ( clk           ),
    .i_bv_a      ( m_bv[3]       ),
    .i_bc_a      ( m_bc[3]       ),
    .i_bv_b      ( m_bv[4]       ),
    .i_bc_b      ( m_bc[4]       ),
    .o_bv        ( n_bv[2]       ),
    .o_bc        ( n_bc[2]       )
);

bitpacker3 bitpacker_31(
    .clk         ( clk           ),
    .i_bv_a      ( n_bv[1]       ),
    .i_bc_a      ( n_bc[1]       ),
    .i_bv_b      ( n_bv[2]       ),
    .i_bc_b      ( n_bc[2]       ),
    .o_bv        ( p_bv          ),
    .o_bc        ( p_bc          )
);

always @ (posedge clk) begin
    m_vl <= rst ? 1'b0 : (l_vl[1]| l_vl[2]| l_vl[3]| l_vl[4]| l_vl[5]| l_vl[6]| l_vl[7]| l_vl[8]);
    n_vl <= rst ? 1'b0 : m_vl;
    p_vl <= rst ? 1'b0 : n_vl;
end

always @ (posedge clk) begin
    o_vl <= rst ? 1'b0 : p_vl;
    o_bv <= p_bv;
    o_bc <= p_bc;
end

endmodule
