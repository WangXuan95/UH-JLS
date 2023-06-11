
//--------------------------------------------------------------------------------------------------------
// Module  : tb_uh_jls
// Type    : simulation only, IP's testbench
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for UH-JLS
//--------------------------------------------------------------------------------------------------------


`define OUT_FILE_DIR          "./"                  // output file (compressed .jls file) directory
`define OUT_FILE_NAME_FORMAT  "out%03d.jls"         // the input and output file names' format


module tb_uh_jls ();


//-------------------------------------------------------------------------------------------------------------------
//   generate clock
//-------------------------------------------------------------------------------------------------------------------
localparam CLK_PERIOD = 10;

reg clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;



//-------------------------------------------------------------------------------------------------------------------
//   signals for uh_jls module
//-------------------------------------------------------------------------------------------------------------------
wire        i_sof;
wire [10:0] i_w;
wire [15:0] i_h;
wire        i_rdy;
wire        i_e;
wire [ 7:0] i_x0, i_x1, i_x2, i_x3, i_x4;
wire        o_e;
wire [63:0] o_data;
wire        o_last;



//-------------------------------------------------------------------------------------------------------------------
// load image and feed image pixels to UH-JLS
//-------------------------------------------------------------------------------------------------------------------
wire [31:0] file_no;

tb_load_and_feed_image #(
    .CLK_PERIOD ( CLK_PERIOD     )
) u_tb_load_and_feed_image (
    .clk        ( clk            ),
    .i_sof      ( i_sof          ),
    .i_w        ( i_w            ),
    .i_h        ( i_h            ),
    .i_rdy      ( i_rdy          ),
    .i_e        ( i_e            ),
    .i_x0       ( i_x0           ),
    .i_x1       ( i_x1           ),
    .i_x2       ( i_x2           ),
    .i_x3       ( i_x3           ),
    .i_x4       ( i_x4           ),
    .file_no    ( file_no        )
);


//-------------------------------------------------------------------------------------------------------------------
// UH-JLS : design under test
//-------------------------------------------------------------------------------------------------------------------
uh_jls u_uh_jls (
    .clk        ( clk            ),
    .i_sof      ( i_sof          ),
    .i_w        ( i_w            ),
    .i_h        ( i_h            ),
    .i_rdy      ( i_rdy          ),
    .i_e        ( i_e            ),
    .i_x0       ( i_x0           ),
    .i_x1       ( i_x1           ),
    .i_x2       ( i_x2           ),
    .i_x3       ( i_x3           ),
    .i_x4       ( i_x4           ),
    .o_e        ( o_e            ),
    .o_data     ( o_data         ),
    .o_last     ( o_last         )
);



//-------------------------------------------------------------------------------------------------------------------
//  write output stream to .jls files 
//-------------------------------------------------------------------------------------------------------------------
reg [256*8:1] output_file_name;
reg [256*8:1] output_file_format;
initial $sformat(output_file_format, "%s\\%s", `OUT_FILE_DIR, `OUT_FILE_NAME_FORMAT);
integer jls_file = 0;

always @ (posedge clk)
    if(o_e) begin
        // the first data of an output stream, open a new file.
        if (jls_file == 0) begin
            $sformat(output_file_name, output_file_format, file_no);
            jls_file = $fopen(output_file_name , "wb");                         // if open failed, it will return 0
        end
        
        // write data to file.
        if (jls_file != 0)
            $fwrite(jls_file, "%c%c%c%c%c%c%c%c", o_data[7:0], o_data[15:8], o_data[23:16], o_data[31:24], o_data[39:32], o_data[47:40], o_data[55:48], o_data[63:56]);
        
        // if it is the last data of an output stream, close the file.
        if (o_last)
            if (jls_file != 0) begin
                $fclose(jls_file);
                jls_file = 0;
            end
    end


endmodule
