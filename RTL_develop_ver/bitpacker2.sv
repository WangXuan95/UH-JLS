`timescale 1 ns/1 ns

module bitpacker2(
    input  wire         clk,
    input  wire [125:0] i_bv_a,
    input  wire [  6:0] i_bc_a,
    input  wire [125:0] i_bv_b,
    input  wire [  6:0] i_bc_b,
    output reg  [191:0] o_bv,
    output reg  [  7:0] o_bc
);

always @ (posedge clk) begin
    o_bv <= {i_bv_a,66'h0} | ( {i_bv_b,66'h0} >> i_bc_a );
    o_bc <= {1'b0,i_bc_a} + {1'b0,i_bc_b};
end

endmodule
