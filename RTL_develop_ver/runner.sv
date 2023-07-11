`timescale 1 ns/1 ns

module runner(
    input  wire        rst,
    input  wire        clk,
    
    input  wire        ena,
    
    input  wire        i_sl,
    input  wire        i_sp,
    input  wire        i_ep,
    input  wire        i_vl,
    input  wire [ 7:0] i_b  [1:10],
    input  wire [ 7:0] i_x  [1:8 ],
    
    output reg         o_sl,
    output reg         o_sp,
    output reg         o_vl,
    output reg  [ 1:0] o_st [1:8 ],
    output reg  [ 7:0] o_b  [1:9 ],
    output reg  [ 7:0] o_x  [1:8 ]
);

function automatic logic near(input [7:0] x1, input [7:0] x2);
    return x1[7:2] == x2[7:2];
    //return x1 == x2;
endfunction

reg         a_sl;
reg         a_sp;
reg         a_ep;
reg         a_vl;
reg  [ 8:1] a_rs;
reg  [ 7:0] a_b  [1:9];
reg  [ 7:0] a_x  [1:8];

reg         b_sl;
reg         b_sp;
reg         b_ep;
reg         b_vl;
reg  [ 8:1] b_rs;
reg  [ 7:0] b_rx [1:8];
reg  [ 7:0] b_b  [1:9];
reg  [ 7:0] b_x  [0:8];

reg         c_sl;
reg         c_sp;
reg         c_ep;
reg         c_vl;
reg  [ 8:1] c_rs;
reg  [ 7:0] c_rx [1:8];
reg  [ 7:0] c_b  [1:9];
reg         c_near [1:8];
reg         c_sp_ri;
reg  [ 7:0] c_sp_c;

reg         d_sl;
reg         d_sp;
reg         d_ep;
reg         d_vl;
reg  [ 1:0] d_st [1:8];
reg  [ 7:0] d_b  [1:9];
reg  [ 7:0] d_x  [1:8];

reg         e_sl;
reg         e_sp;
reg         e_ep;
reg         e_vl;
reg  [ 1:0] e_st [1:8];
reg  [ 7:0] e_b  [1:9];
reg  [ 7:0] e_x  [1:8];

reg         run_valid;

always @ (posedge clk)
    if(ena) begin
        a_sl <= i_sl;
        a_sp <= i_sp;
        a_ep <= i_ep;
        a_vl <= i_vl;
        for(int i=1; i<=6; i++)
            a_rs[i] <= ( i_b[i]==i_b[i+1] && i_b[i+1]==i_b[i+2] ) && ( i_b[i]==i_x[i] || near(i_b[i],i_x[i]) && near(i_b[i+1],i_x[i+1]) && near(i_b[i+2],i_x[i+2]) );
        a_rs[7] <= i_b[7]==i_b[8] && i_b[8]==i_b[9] && ( i_b[7]==i_x[7] || near(i_b[7],i_x[7]) && near(i_b[8],i_x[8]) );
        a_rs[8] <= i_b[8]==i_b[9] && i_b[9]==i_b[10] && i_b[8]==i_x[8];
        a_b <= i_b[1:9];
        a_x <= i_x;
    end else if(rst) begin
        a_sl <= '0;
        a_sp <= '0;
        a_ep <= '0;
        a_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        b_sl <= a_sl;
        b_sp <= a_sp;
        b_ep <= a_ep;
        b_vl <= a_vl;
        b_rs <= a_rs;
        for(int i=1; i<=8; i++)
            b_rx[i] <= a_rs[i] ? a_b[i] : a_x[i];
        b_b <= a_b;
        b_x[0] <= a_sp ? a_b[1] : b_x[8];
        for(int i=1; i<=8; i++)
            b_x[i] <= a_x[i];
    end else if(rst) begin
        b_sl <= '0;
        b_sp <= '0;
        b_ep <= '0;
        b_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        c_sl <= b_sl;
        c_sp <= b_sp;
        c_ep <= b_ep;
        c_vl <= b_vl;
        c_rs <= b_rs;
        c_rx <= b_rx;
        c_b <= b_b;
        for(int i=1; i<=8; i++) begin
            c_near[i] <= near(b_x[i], b_x[i-1]);
        end
        c_sp_ri <= c_sp_c == b_b[1] && b_b[2] == b_b[1];
        c_sp_c <= b_sp ? b_b[1] : c_sp_c;
    end else if(rst) begin
        c_sl <= '0;
        c_sp <= '0;
        c_ep <= '0;
        c_vl <= '0;
        c_sp_ri <= '0;
        c_sp_c <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        automatic logic [7:0] run_pixel;
        run_valid = c_sp ? c_sp_ri : run_valid;
        run_pixel = c_sp ? c_sp_c : d_x[8];
        for(int i=1; i<=8; i++) begin
            if( run_valid & c_near[i] ) begin
                d_x[i] <= run_pixel;
                d_st[i] <= 2'd1;
            end else begin
                d_x[i] <= c_rx[i];
                d_st[i] <= {run_valid, 1'b0};
                run_valid = c_rs[i];
                run_pixel = c_rx[i];
            end
        end
        d_sl <= c_sl;
        d_sp <= c_sp;
        d_ep <= c_ep;
        d_vl <= c_vl;
        d_b <= c_b;
    end else if(rst) begin
        run_valid = 1'b0;
        d_sl <= '0;
        d_sp <= '0;
        d_ep <= '0;
        d_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        e_sl <= d_sl;
        e_sp <= d_sp;
        e_ep <= d_ep;
        e_vl <= d_vl;
        e_st <= d_st;
        e_b  <= d_b;
        e_x  <= d_x;
    end else if(rst) begin
        e_sl <= '0;
        e_sp <= '0;
        e_ep <= '0;
        e_vl <= '0;
    end

always @ (posedge clk)
    if(ena) begin
        o_sl <= e_sl;
        o_sp <= e_sp;
        o_vl <= e_vl;
        o_st <= e_st;
        if(e_ep && e_st[8]==2'd1)
            o_st[8] <= 2'd3;
        o_b <= e_b;
        o_x <= e_x;
    end else if(rst) begin
        o_sl <= '0;
        o_sp <= '0;
        o_vl <= '0;
    end
    
endmodule
