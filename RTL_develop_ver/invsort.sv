`timescale 1 ns/1 ns

// 2 stage pipeline
module invsort(
    input  wire        rst,
    input  wire        clk,
    input  wire        i_et,
    input  wire [ 3:0] i_ql  [1:8],
    input  wire        i_vl  [0:13],
    input  wire [ 4:0] i_oc,
    input  wire [14:0] i_pv,
    input  wire [ 3:0] i_pc,
    input  wire [ 4:0] i_zc  [0:13],
    input  wire [ 8:0] i_bv  [0:13],
    input  wire [ 3:0] i_bc  [0:13],
    output reg         o_et,
    output reg         o_vl  [1:8],
    output reg  [ 4:0] o_oc  [1:8],
    output reg  [14:0] o_pv  [1:8],
    output reg  [ 3:0] o_pc  [1:8],
    output reg  [ 4:0] o_zc  [1:8],
    output reg  [ 8:0] o_bv  [1:8],
    output reg  [ 3:0] o_bc  [1:8]
);

reg        a_et;
reg [ 3:0] a_ql    [1:8];
reg        a_isrun [1:8];
reg        a_vl  [0:15];
reg [ 4:0] a_oc;
reg [14:0] a_pv;
reg [ 3:0] a_pc;
reg [ 4:0] a_zc  [0:15];
reg [ 8:0] a_bv  [0:15];
reg [ 3:0] a_bc  [0:15];

always_comb begin
    a_vl[14] = 1'b0;
    a_vl[15] = 1'b0;
    a_zc[14] = '0;
    a_zc[15] = '0;
    a_bv[14] = '0;
    a_bv[15] = '0;
    a_bc[14] = '0;
    a_bc[15] = '0;
end

always @ (posedge clk) begin
    a_et <= rst ? 1'b0 : i_et;
    a_ql <= i_ql;
    for(int ii=1; ii<=8; ii++) a_isrun[ii] <= i_ql[ii] == 4'd13;
    a_oc <= i_oc;
    a_pv <= i_pv;
    a_pc <= i_pc;
    for(int jj=0; jj<=13; jj++) begin
        a_vl[jj] <= rst ? '0 : i_vl[jj];
        a_zc[jj] <= i_zc[jj];
        a_bv[jj] <= i_bv[jj];
        a_bc[jj] <= i_bc[jj];
    end
end

always @ (posedge clk) begin
    o_et <= rst ? 1'b0 : a_et;
    for(int ii=1; ii<=8; ii++) begin
        automatic logic [3:0] sel = a_ql[ii];
        o_vl[ii] <= rst ? 1'b0 : a_vl[sel];
        o_zc[ii] <= rst ? '0 : a_zc[sel];
        o_bv[ii] <= rst ? '0 : a_bv[sel];
        o_bc[ii] <= rst ? '0 : a_bc[sel];
        o_oc[ii] <= a_isrun[ii] ? a_oc : '0;
        o_pv[ii] <= a_isrun[ii] ? a_pv : '0;
        o_pc[ii] <= a_isrun[ii] ? a_pc : '0;
    end
end

endmodule
