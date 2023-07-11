`timescale 1 ns/1 ns

// 
module channelpacker(
    input  wire        rst,
    input  wire        clk,
    input  wire        i_vl,
    input  wire [ 4:0] i_oc,
    input  wire [14:0] i_pv,
    input  wire [ 3:0] i_pc,
    input  wire [ 4:0] i_zc,
    input  wire [ 8:0] i_bv,
    input  wire [ 3:0] i_bc,
    output reg         o_vl,
    output reg  [62:0] o_bv,
    output reg  [ 5:0] o_bc
);

reg        a_vl;
reg [46:0] a_pv;
reg [ 5:0] a_pc;
reg [46:0] a_bv;
reg [ 5:0] a_bc;

reg         b_vl;
reg  [62:0] b_bv;
reg  [ 5:0] b_bc;

always @ (posedge clk) begin
    a_vl <= ~rst & i_vl;
    a_pv <= (47'h7fff_ffff_ffff << i_pc) | {32'h0, i_pv};
    a_pc <= {1'b0, i_oc} + {2'b0, i_pc};
    a_bv <= ({46'h0, |i_zc} << i_bc) | {38'h0, (i_bv & ~(9'h1ff<<i_bc))};
    a_bc <= {1'b0, i_zc} + {2'b0, i_bc};
end

always @ (posedge clk) begin
    b_vl <= ~rst & a_vl;
    b_bv <= ({16'h0,a_pv} << 6'd63-a_pc) | ({16'h0,a_bv} << 6'd63-a_pc-a_bc);
    b_bc <= a_pc + a_bc;
end

always @ (posedge clk) begin
    o_vl <= ~rst & b_vl;
    o_bv <= b_vl ? b_bv : '0;
    o_bc <= b_vl ? b_bc : '0;
end

endmodule
