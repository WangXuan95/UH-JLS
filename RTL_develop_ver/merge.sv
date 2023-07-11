`timescale 1 ns/1 ns

module merge(
    input  wire        rst,
    input  wire        clk,
    input  wire        i_et,
    input  wire        i_vl  [1:8],
    input  wire [ 4:0] i_oc  [1:8],
    input  wire [14:0] i_pv  [1:8],
    input  wire [ 3:0] i_pc  [1:8],
    input  wire [ 4:0] i_zc  [1:8],
    input  wire [ 8:0] i_bv  [1:8],
    input  wire [ 3:0] i_bc  [1:8],
    output reg         o_vl  [1:8],
    output reg  [ 4:0] o_oc  [1:8],
    output reg  [14:0] o_pv  [1:8],
    output reg  [ 3:0] o_pc  [1:8],
    output reg  [ 4:0] o_zc  [1:8],
    output reg  [ 8:0] o_bv  [1:8],
    output reg  [ 3:0] o_bc  [1:8]
);

reg        a_vl [1:7];
reg [ 4:0] a_oc [1:7];
reg [14:0] a_pv [1:7];
reg [ 3:0] a_pc [1:7];
reg [ 4:0] a_zc [1:7];
reg [ 8:0] a_bv [1:7];
reg [ 3:0] a_bc [1:7];

always @ (posedge clk) begin
    for(int i=1; i<=7; i++) begin
        if(rst) begin
            a_vl[i] <= 1'b0;
            o_vl[i] <= 1'b0;
        end else if(i_et) begin
            a_vl[i] <= 1'b0;
            o_vl[i] <= a_vl[i] | i_vl[i];
            o_oc[i] <= i_vl[i] ? i_oc[i] : a_oc[i];
            o_pv[i] <= i_vl[i] ? i_pv[i] : a_pv[i];
            o_pc[i] <= i_vl[i] ? i_pc[i] : a_pc[i];
            o_zc[i] <= i_vl[i] ? i_zc[i] : a_zc[i];
            o_bv[i] <= i_vl[i] ? i_bv[i] : a_bv[i];
            o_bc[i] <= i_vl[i] ? i_bc[i] : a_bc[i];
        end else if(i_vl[i]) begin
            a_vl[i] <= 1'b1;
            a_oc[i] <= i_oc[i];
            a_pv[i] <= i_pv[i];
            a_pc[i] <= i_pc[i];
            a_zc[i] <= i_zc[i];
            a_bv[i] <= i_bv[i];
            a_bc[i] <= i_bc[i];
            o_vl[i] <= 1'b0;
        end else begin
            o_vl[i] <= 1'b0;
        end
    end
    o_vl[8] <= ~rst & i_et & i_vl[8];
    if(i_et) begin
        o_oc[8] <= i_oc[8];
        o_pv[8] <= i_pv[8];
        o_pc[8] <= i_pc[8];
        o_zc[8] <= i_zc[8];
        o_bv[8] <= i_bv[8];
        o_bc[8] <= i_bc[8];
    end
end

endmodule
