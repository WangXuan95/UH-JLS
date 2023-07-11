`timescale 1 ns/1 ns

module shuffler(
    input  wire        rst,
    input  wire        clk,
    input  wire        ena,
    input  wire        i_sp,
    input  wire        i_vl,
    input  wire [ 1:0] i_st [1:8],
    input  wire [ 7:0] i_b  [0:9],
    input  wire [ 7:0] i_x  [0:8],
    output reg         o_sp,
    output reg         o_vl,
    output reg  [ 7:0] o_b   [0:8],
    output reg  [ 7:0] o_x   [0:8],
    output reg         o_s   [1:8],
    output reg  [ 4:0] o_qh  [1:8],
    output reg  [ 3:0] o_ql  [1:8],
    output reg  [ 2:0] o_qcnt[1:8]
);

function automatic logic near(input [7:0] x1, input [7:0] x2);
    return x1[7:2] == x2[7:2];
    //return x1 == x2;
endfunction

function automatic logic signed [3:0] quant(input [7:0] a, input [7:0] b);
    automatic logic signed [8:0] delta = $signed({1'b0,a}) - $signed({1'b0,b});
    if     (delta <= -$signed(9'd21))
        return -$signed(4'd4);
    else if(delta <= -$signed(9'd7) )
        return -$signed(4'd3);
    else if(delta <= -$signed(9'd3) )
        return -$signed(4'd2);
    else if(delta <   $signed(9'd0) )
        return -$signed(4'd1);
    else if(delta ==  $signed(9'd0) )
        return  $signed(4'd0);
    else if(delta <   $signed(9'd3) )
        return  $signed(4'd1);
    else if(delta <   $signed(9'd7) )
        return  $signed(4'd2);
    else if(delta <   $signed(9'd21))
        return  $signed(4'd3);
    else
        return  $signed(4'd4);
endfunction

function automatic logic signed [9:0] calc_qa(input [7:0] c, input [7:0] b, input [7:0] d);
    return $signed(10'd81) * quant(d,b) + $signed(10'd9) * quant(b,c);
endfunction

function automatic logic [9:0] calc_s_q(input signed [9:0] qa, input signed [3:0] qb);
    automatic logic signed [9:0] qs;
    automatic logic              s;
    automatic logic        [8:0] q;
    qs = qa + qb;
    s = qs[9];
    q = s ? (~qs[8:0]+9'd1) : qs[8:0];
    q -= 9'd1;
    return {s,q};
endfunction

function automatic logic [15:0] candidate(input [7:0] c, input [7:0] a);
    automatic logic signed [8:0] delta = $signed({1'b0,c}) - $signed({1'b0,a});
    automatic logic        [7:0] ap, an;
    if         (delta <= -$signed(9'd21)) begin
        ap = c + 8'd21;
        an = c + 8'd20;
    end else if(delta <= -$signed(9'd7 )) begin
        ap = c + 8'd21;
        an = c + 8'd6;
    end else if(delta <= -$signed(9'd3 )) begin
        ap = c + 8'd7;
        an = c + 8'd2;
    end else if(delta <   $signed(9'd0 )) begin
        ap = c + 8'd3;
        an = c - 8'd1;   // modified@20200312, origin: an = c;
    end else if(delta ==  $signed(9'd0 )) begin
        ap = c + 8'd1;
        an = c - 8'd1;
    end else if(delta <   $signed(9'd3 )) begin
        ap = c + 8'd1;   // modified@20200312, origin: an = c;
        an = c - 8'd3;
    end else if(delta <   $signed(9'd7 )) begin
        ap = c - 8'd2;
        an = c - 8'd7;
    end else if(delta <   $signed(9'd21)) begin
        ap = c - 8'd6;
        an = c - 8'd21;
    end else begin
        ap = c - 8'd20;
        an = c - 8'd21;
    end
    if(~near(an,a))
        an = a;
    if(~near(ap,a))
        ap = a;
    return {ap,an};
endfunction

function automatic logic [8:0] get_qh_ql(input [8:0] q);
    automatic logic [8:0] qhe;
    automatic logic [8:0] qle;
    qhe = q / 9'd13;
    qle = q % 9'd13;
    return {qhe[4:0], qle[3:0]};
endfunction

reg               a_sp;
reg               a_vl;
reg         [1:0] a_st  [1:8];
reg         [7:0] a_b   [0:8];
reg         [7:0] a_x   [0:8];
reg         [7:0] a_x_p [1:7];
reg         [7:0] a_x_n [1:7];
reg  signed [9:0] a_qa  [1:8];

always @ (posedge clk)
    if(ena) begin
        a_sp <= i_sp;
        a_vl <= i_vl;
        a_st <= i_st;
        for(int i=0; i<=8; i++)
            a_b[i] <= i_b[i];
        a_x <= i_x;
        for(int i=1; i<=7; i++)
            {a_x_p[i], a_x_n[i]} <= candidate(i_b[i], i_x[i]);
        for(int i=1; i<=8; i++)
            a_qa[i] <= calc_qa(i_b[i-1],i_b[i],i_b[i+1]);
    end else if(rst) begin
        a_sp <= '0;
        a_vl <= '0;
    end

reg               b_sp;
reg               b_vl;
reg         [1:0] b_st  [1:8];
reg         [7:0] b_b   [0:8];
reg         [7:0] b_x   [0:8];
reg         [7:0] b_x_p [1:7];
reg         [7:0] b_x_n [1:7];
reg  signed [9:0] b_qa  [1:8];
reg  signed [3:0] b_qb  [1:8];
reg  signed [3:0] b_qb_p[2:8];
reg  signed [3:0] b_qb_n[2:8];

always @ (posedge clk)
    if(ena) begin
        b_sp <= a_sp;
        b_vl <= a_vl;
        b_st <= a_st;
        b_b <= a_b;
        b_x <= a_x;
        b_x_p <= a_x_p;
        b_x_n <= a_x_n;
        b_qa <= a_qa;
        b_qb[1] <= quant(a_b[0], a_x[0]);
        for(int i=2; i<=8; i++) begin
            b_qb[i]   <= quant(a_b[i-1],   a_x[i-1]);
            b_qb_p[i] <= quant(a_b[i-1], a_x_p[i-1]);
            b_qb_n[i] <= quant(a_b[i-1], a_x_n[i-1]);
        end
    end else if(rst) begin
        b_sp <= '0;
        b_vl <= '0;
    end

reg               c_sp;
reg               c_vl;
reg         [1:0] c_st  [1:8];
reg         [7:0] c_b   [0:8];
reg         [7:0] c_x   [0:8];
reg         [7:0] c_x_p [1:7];
reg         [7:0] c_x_n [1:7];
reg               c_s   [1:8];
reg         [8:0] c_q   [1:8];
reg               c_s_p [2:8];
reg         [8:0] c_q_p [2:8];
reg               c_s_n [2:8];
reg         [8:0] c_q_n [2:8];
reg         [1:0] c_ri  [1:8];

always @ (posedge clk)
    if(ena) begin
        c_sp <= b_sp;
        c_vl <= b_vl;
        c_st <= b_st;
        c_b  <= b_b;
        c_x  <= b_x;
        c_x_p<= b_x_p;
        c_x_n<= b_x_n;
        {c_s[1], c_q[1]} <= calc_s_q(b_qa[1], b_qb[1]);
        c_ri[1][1] <= b_x[0]> b_b[1];
        c_ri[1][0] <= b_x[0]==b_b[1];
        for(int i=2; i<=8; i++) begin
            {  c_s[i],   c_q[i]} <= calc_s_q(b_qa[i], b_qb[i]);
            {c_s_p[i], c_q_p[i]} <= calc_s_q(b_qa[i], b_qb_p[i]);
            {c_s_n[i], c_q_n[i]} <= calc_s_q(b_qa[i], b_qb_n[i]);
            c_ri[i][1] <= b_x[i-1]> b_b[i];
            c_ri[i][0] <= b_x[i-1]==b_b[i];
        end
    end else if(rst) begin
        c_sp <= '0;
        c_vl <= '0;
    end

reg               d_sp  [1:8];
reg               d_vl  [1:8];
reg         [7:0] d_b   [1:8][0:8];
reg         [7:0] d_x   [1:8][0:8];
reg         [7:0] d_x_p [1:8][1:7];
reg         [7:0] d_x_n [1:8][1:7];
reg               d_s   [1:8][1:8];
reg         [4:0] d_qh  [1:8][1:8];
reg         [3:0] d_ql  [1:8][1:8];
reg               d_s_p [1:8][2:8];
reg         [4:0] d_qh_p[1:8][2:8];
reg         [3:0] d_ql_p[1:8][2:8];
reg               d_s_n [1:8][2:8];
reg         [4:0] d_qh_n[1:8][2:8];
reg         [3:0] d_ql_n[1:8][2:8];
reg         [2:0] d_qcnt[1:8][1:8];

always_comb
    d_qcnt[1] <= '{8{'0}};

always @ (posedge clk)
    if(ena) begin
        d_sp[1] <= c_sp;
        d_vl[1] <= c_vl;
        d_b[1]  <= c_b;
        d_x[1]  <= c_x;
        d_x_p[1]<= c_x_p;
        d_x_n[1]<= c_x_n;
        d_s[1]  <= c_s;
        d_s_p[1]<= c_s_p;
        d_s_n[1]<= c_s_n;
        if         (c_st[1]==2'd0) begin
            {d_qh[1][1], d_ql[1][1]} <= get_qh_ql(c_q[1]);
        end else if(c_st[1]==2'd1) begin
            {d_qh[1][1], d_ql[1][1]} <= '1;
        end else if(c_st[1]==2'd2) begin
            {d_qh[1][1], d_ql[1][1]} <= {3'd0, c_ri[1], 4'd13};
        end else begin
            {d_qh[1][1], d_ql[1][1]} <= {5'd31, 4'd13};
        end
        for(int i=2; i<=8; i++) begin
            if         (c_st[i]==2'd0) begin
                {  d_qh[1][i],   d_ql[1][i]} <= get_qh_ql(  c_q[i]);
                {d_qh_p[1][i], d_ql_p[1][i]} <= get_qh_ql(c_q_p[i]);
                {d_qh_n[1][i], d_ql_n[1][i]} <= get_qh_ql(c_q_n[i]);
            end else if(c_st[i]==2'd1) begin
                {  d_qh[1][i],   d_ql[1][i]} <= '1;
                {d_qh_p[1][i], d_ql_p[1][i]} <= '1;
                {d_qh_n[1][i], d_ql_n[1][i]} <= '1;
            end else if(c_st[i]==2'd2) begin
                {  d_qh[1][i],   d_ql[1][i]} <= {3'd0, c_ri[i], 4'd13};
                {d_qh_p[1][i], d_ql_p[1][i]} <= {3'd0, c_ri[i], 4'd13};
                {d_qh_n[1][i], d_ql_n[1][i]} <= {3'd0, c_ri[i], 4'd13};
            end else begin
                {  d_qh[1][i],   d_ql[1][i]} <= {5'd31, 4'd13};
                {d_qh_p[1][i], d_ql_p[1][i]} <= {5'd31, 4'd13};
                {d_qh_n[1][i], d_ql_n[1][i]} <= {5'd31, 4'd13};
            end
        end
    end else if(rst) begin
        d_sp[1] <= '0;
        d_vl[1] <= '0;
    end

generate genvar kk; for(kk=1; kk<=7; kk++) begin : gen_shuffler
always @ (posedge clk)
    if(ena) begin
        automatic logic [2:0] cc='0, cp='0, cn='0;
        for(int i=1; i<=8; i++) begin
            if(i!=(kk+1)) begin
                if( d_ql[kk][i] ==   d_ql[kk][kk+1] ) cc++;
                if( d_ql[kk][i] == d_ql_p[kk][kk+1] ) cp++;
                if( d_ql[kk][i] == d_ql_n[kk][kk+1] ) cn++;
            end
        end
        d_sp[kk+1] <= d_sp[kk];
        d_vl[kk+1] <= d_vl[kk];
        d_b[kk+1]  <= d_b[kk];
        d_x[kk+1] <= d_x[kk];
        d_x_p[kk+1]<= d_x_p[kk];
        d_x_n[kk+1]<= d_x_n[kk];
        d_s[kk+1] <= d_s[kk];
        d_qh[kk+1] <= d_qh[kk];
        d_ql[kk+1] <= d_ql[kk];
        d_s_p[kk+1]<= d_s_p[kk];
        d_qh_p[kk+1]<= d_qh_p[kk];
        d_ql_p[kk+1]<= d_ql_p[kk];
        d_s_n[kk+1]<= d_s_n[kk];
        d_qh_n[kk+1]<= d_qh_n[kk];
        d_ql_n[kk+1]<= d_ql_n[kk];
        for(int i=1; i<=8; i++) begin
            d_qcnt[kk+1][i] <= d_qcnt[kk][i] + ( (i<kk && d_ql[kk][i]==d_ql[kk][kk] && d_ql[kk][kk]!='1) ? 3'd1 : 3'd0 );
        end
        if     (cp<cc || cn<cc) begin
            if(cn<cp)
                {d_s[kk+1][kk+1], d_qh[kk+1][kk+1], d_ql[kk+1][kk+1], d_x[kk+1][kk]} <= {d_s_n[kk][kk+1], d_qh_n[kk][kk+1], d_ql_n[kk][kk+1], d_x_n[kk][kk]};
            else
                {d_s[kk+1][kk+1], d_qh[kk+1][kk+1], d_ql[kk+1][kk+1], d_x[kk+1][kk]} <= {d_s_p[kk][kk+1], d_qh_p[kk][kk+1], d_ql_p[kk][kk+1], d_x_p[kk][kk]};
        end
    end else if(rst) begin
        d_sp[kk+1] <= '0;
        d_vl[kk+1] <= '0;
    end
end endgenerate

always @ (posedge clk)
    if(ena) begin
        o_sp <= d_sp[8];
        o_vl <= d_vl[8];
        o_b  <= d_b[8];
        o_x  <= d_x[8];
        o_s  <= d_s[8];
        o_qh <= d_qh[8];
        o_ql <= d_ql[8];
        for(int i=1; i<=8; i++) begin
            o_qcnt[i] <= d_qcnt[8][i] + ( (i<8 && d_ql[8][i]==d_ql[8][8] && d_ql[8][8]!='1) ? 3'd1 : 3'd0 );
        end
    end else if(rst) begin
        o_sp <= '0;
        o_vl <= '0;
    end

endmodule
