`timescale 1 ns/1 ns

module bitpacker3(
    input  wire         clk,
    input  wire [191:0] i_bv_a,
    input  wire [  7:0] i_bc_a,
    input  wire [191:0] i_bv_b,
    input  wire [  7:0] i_bc_b,
    output reg  [191:0] o_bv,
    output reg  [  7:0] o_bc
);

always @ (posedge clk) begin
    o_bv <= i_bv_a | ( i_bv_b >> i_bc_a );
    o_bc <= i_bc_a + i_bc_b;
end

endmodule
