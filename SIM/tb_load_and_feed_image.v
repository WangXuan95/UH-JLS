
//--------------------------------------------------------------------------------------------------------
// Module  : tb_load_and_feed_image
// Type    : simulation only, IP's testbench's submodule
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: Load Pixels from .pgm files, and feed them via output ports
//--------------------------------------------------------------------------------------------------------


`define IN_FILE_DIR          "./images"             // input file (uncompressed .pgm file) directory
`define IN_FILE_NAME_FORMAT  "test%03d.pgm"         // the input and output file names' format


`define BUBBLE_CONTROL    0                  // bubble numbers that insert between pixels
                                             //    when = 0, do not insert bubble
                                             //    when > 0, insert BUBBLE_CONTROL bubbles
                                             //    when < 0, insert random 0~(-BUBBLE_CONTROL) bubbles


module tb_load_and_feed_image #(
    parameter CLK_PERIOD = 10
) (
    input  wire       clk,
    output reg        i_sof,
    output reg [10:0] i_w,
    output reg [15:0] i_h,
    input  wire       i_rdy,
    output reg        i_e,
    output reg [ 7:0] i_x0, i_x1, i_x2, i_x3, i_x4,
    output reg [31:0] file_no
);



initial i_sof = 1'b0;
initial i_e   = 1'b0;



//-------------------------------------------------------------------------------------------------------------------
//   2-D array to save image pixels
//-------------------------------------------------------------------------------------------------------------------
reg [15:0] img [0:16382] [0:10239];               // saves the image, maximum height=16383, width=10240
integer w, h;                                     // image width and height



//-------------------------------------------------------------------------------------------------------------------
//   function: load image to array from PGM file, support both 8bit or 16bit PGM image.
//   arguments:
//        fname: input .pgm file name
//   return:
//        0  : success
//        -1 : failed
//-------------------------------------------------------------------------------------------------------------------
function integer load_img;
    input [256*8:1] fname;
    integer linelen, depth, scanf_num, byte_per_pixel, fp, ii, jj, k;
    reg   [256*8-1:0] line;
begin
    load_img = -1;
    depth=0;
    byte_per_pixel=0;
    fp = $fopen(fname, "rb");
    if (fp == 0) begin
        //$display("*** error in load_img : could not open file.");
    end else begin
        linelen = $fgets(line, fp);
        if (line[8*(linelen-2)+:16] != 16'h5035) begin
            $display("*** error in load_img: the first line must be P5");
            $fclose(fp);
        end else begin
            scanf_num = $fgets(line, fp);
            scanf_num = $sscanf(line, "%d%d", w, h);
            if (scanf_num == 1) begin
                scanf_num = $fgets(line, fp);
                scanf_num = $sscanf(line, "%d", h);
            end
            scanf_num = $fgets(line, fp);
            scanf_num = $sscanf(line, "%d", depth);
            if (depth < 1)
                depth = 1;
            if (depth > 65535)
                depth = 65535;
            byte_per_pixel = (depth < 256) ? 1 : 2;
            for (jj=0; jj<h; jj=jj+1) begin
                for (ii=0; ii<w; ii=ii+1) begin
                    img[jj][ii] = 0;
                    for (k=0; k<byte_per_pixel; k=k+1) begin
                        img[jj][ii] = img[jj][ii] << 8;
                        img[jj][ii] = img[jj][ii] + $fgetc(fp);
                    end
                end
            end
            $fclose(fp);
            load_img = 0;
        end
    end
end
endfunction



//-------------------------------------------------------------------------------------------------------------------
//   task: feed image pixels to jls_encoder_i module
//   arguments:
//         w_d5   : image width / 5
//         h      : image height
//         bubble_control : bubble numbers that insert between pixels
//              when = 0, do not insert bubble
//              when > 0, insert bubble_control bubbles
//              when < 0, insert random 0~bubble_control bubbles
//-------------------------------------------------------------------------------------------------------------------
task feed_img;
    input integer w_d5, h, bubble_control;
    integer num_bubble, jj, ii;
begin
    // start feeding a image by assert i_sof=1 for at least 50 cycles
    repeat (50) @(posedge clk) begin
        i_sof <= 1'b1;
        i_w <= w_d5 - 1;
        i_h <= h - 1;
        i_e <= 1'b0;
        {i_x0, i_x1, i_x2, i_x3, i_x4} <= 0;
    end
    
    @(posedge clk) begin
        i_sof <= 1'b0;
        i_w <= 'hXXXXXXXX;
        i_h <= 'hXXXXXXXX;
    end
    
    // for all pixels of the image ------------------------------------------------------
    for (jj=0; jj<h; jj=jj+1) begin
        for (ii=0; ii<w_d5; ii=ii+1) begin
            
            // calculate how many bubbles to insert
            if (bubble_control<0) begin
                num_bubble = $random % (1-bubble_control);
                if (num_bubble<0)
                    num_bubble = -num_bubble;
            end else begin
                num_bubble = bubble_control;
            end
            
            // insert bubbles
            repeat(num_bubble) begin
                @(posedge clk) begin
                    i_e <= 0;
                    {i_x0, i_x1, i_x2, i_x3, i_x4} <= 0;
                end
            end
            
            // feed a data (5 pixels)
            @(posedge clk) begin
                i_e <= 1'b1;
                i_x0 <= img[jj][5*ii+0];
                i_x1 <= img[jj][5*ii+1];
                i_x2 <= img[jj][5*ii+2];
                i_x3 <= img[jj][5*ii+3];
                i_x4 <= img[jj][5*ii+4];
            end
            @(negedge clk);
            while (~i_rdy) begin
                @(posedge clk) begin
                    i_e <= 1'b1;
                    i_x0 <= img[jj][5*ii+0];
                    i_x1 <= img[jj][5*ii+1];
                    i_x2 <= img[jj][5*ii+2];
                    i_x3 <= img[jj][5*ii+3];
                    i_x4 <= img[jj][5*ii+4];
                end
                @(negedge clk);
            end
        end
    end
    
    // at least 500 cycles idle between images
    repeat (500) @(posedge clk) begin
        i_e <= 0;
        {i_x0, i_x1, i_x2, i_x3, i_x4} <= 0;
    end
end
endtask



//-------------------------------------------------------------------------------------------------------------------
//  read images, feed them to jls_encoder_i module 
//-------------------------------------------------------------------------------------------------------------------
reg [256*8:1] input_file_name;
reg [256*8:1] input_file_format;

reg [63:0] start_time, cycles;

initial begin
    $sformat(input_file_format , "%s\\%s",  `IN_FILE_DIR, `IN_FILE_NAME_FORMAT);
    
    repeat (4) @ (posedge clk);

    for (file_no=0; file_no<=999; file_no=file_no+1) begin
        $sformat(input_file_name, input_file_format , file_no);

        if ( !load_img(input_file_name) ) begin                                   // if image load success
            w = (w/5)*5;                                                          // if image width is not integer multiple of 5, clip it to integer multiple of 5
            
            $display("test%03d.pgm   width=%-5d   height=%-5d", file_no, w, h);

            if ( w < 1 || w > 10240 || h < 1 || h > 16383 ) begin                 // image size not supported
                $display("  *** image size not supported, skip");
            end else begin
                start_time = $time;
                feed_img((w/5), h, `BUBBLE_CONTROL);
                cycles = ($time - start_time) / CLK_PERIOD;
                $display("  pixels=%-9d   cycles=%-9d   ppc=%f" , (w*h) , cycles , (1.0*w*h/cycles) );
            end
        end
    end
    
    repeat(1000) @(posedge clk);

    $finish;
end


endmodule
