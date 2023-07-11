`timescale 1 ns/1 ns

// 11 stage pipeline
module bypass(
    input  wire        rst,
    input  wire        clk,
    input  wire        i_et,
    input  wire [ 3:0] i_ql  [1:8],
    output reg         o_et,
    output reg  [ 3:0] o_ql  [1:8]
);

reg        a_et;
reg [ 3:0] a_ql  [1:8];
reg        b_et;
reg [ 3:0] b_ql  [1:8];
reg        c_et;
reg [ 3:0] c_ql  [1:8];
reg        d_et;
reg [ 3:0] d_ql  [1:8];
reg        e_et;
reg [ 3:0] e_ql  [1:8];
reg        f_et;
reg [ 3:0] f_ql  [1:8];
reg        g_et;
reg [ 3:0] g_ql  [1:8];
reg        h_et;
reg [ 3:0] h_ql  [1:8];
reg        j_et;
reg [ 3:0] j_ql  [1:8];
reg        k_et;
reg [ 3:0] k_ql  [1:8];

always @ (posedge clk)
    if(rst) begin
        a_et <= 1'b0;
        a_ql <= '{8{4'hf}};
        b_et <= 1'b0;
        b_ql <= '{8{4'hf}};
        c_et <= 1'b0;
        c_ql <= '{8{4'hf}};
        d_et <= 1'b0;
        d_ql <= '{8{4'hf}};
        e_et <= 1'b0;
        e_ql <= '{8{4'hf}};
        f_et <= 1'b0;
        f_ql <= '{8{4'hf}};
        g_et <= 1'b0;
        g_ql <= '{8{4'hf}};
        h_et <= 1'b0;
        h_ql <= '{8{4'hf}};
        j_et <= 1'b0;
        j_ql <= '{8{4'hf}};
        k_et <= 1'b0;
        k_ql <= '{8{4'hf}};
        o_et <= 1'b0;
        o_ql <= '{8{4'hf}};
    end else begin
        a_et <= i_et;
        a_ql <= i_ql;
        b_et <= a_et;
        b_ql <= a_ql;
        c_et <= b_et;
        c_ql <= b_ql;
        d_et <= c_et;
        d_ql <= c_ql;
        e_et <= d_et;
        e_ql <= d_ql;
        f_et <= e_et;
        f_ql <= e_ql;
        g_et <= f_et;
        g_ql <= f_ql;
        h_et <= g_et;
        h_ql <= g_ql;
        j_et <= h_et;
        j_ql <= h_ql;
        k_et <= j_et;
        k_ql <= j_ql;
        o_et <= k_et;
        o_ql <= k_ql;
    end

endmodule
