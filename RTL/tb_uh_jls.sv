`timescale 1ns/1ns

// bubble numbers that insert between pixels
//    when = 0, do not insert bubble
//    when > 0, insert BUBBLE_CONTROL bubbles
//    when < 0, insert random 0~(-BUBBLE_CONTROL) bubbles
`define BUBBLE_CONTROL 0

// the input and output file names' format
`define FILE_NAME_FORMAT  "test%03d"

// input file (uncompressed .pgm file) directory
`define INPUT_PGM_DIR     "E:\\FPGAcommon\\JPEG-LS\\images"

// output file (compressed .jls file) directory
`define OUTPUT_JLS_DIR    "E:\\FPGAcommon\\JPEG-LS\\images_jls"


module tb_uh_jls();

// -------------------------------------------------------------------------------------------------------------------
//   generate clock
// -------------------------------------------------------------------------------------------------------------------
reg       clk = 1'b0; always #5 clk = ~clk;  // 100MHz


// -------------------------------------------------------------------------------------------------------------------
//   signals for jls_encoder_i module
// -------------------------------------------------------------------------------------------------------------------
reg        rstn = '0;
reg [10:0] i_w = '0;
reg [15:0] i_h = '0;
wire       i_rdy;
reg        i_e = '0;
reg [ 7:0] i_x [5] = '{5{'0}};
wire       o_e;
wire[63:0] o_data;
wire       o_last;


// -------------------------------------------------------------------------------------------------------------------
//   function: load image to array from PGM file, support both 8bit or 16bit PGM image.
//   arguments:
//        fname: input .pgm file name
//        img  : image array
//        w   : image width
//        h   : image height
//   return:
//        0  : success
//        -1 : failed
// -------------------------------------------------------------------------------------------------------------------
function automatic int load_img(input logic [256*8:1] fname, ref logic [15:0] img [][], ref int w, ref int h);
    int linelen, depth=0, scanf_num, byte_per_pixel=0;
    logic [256*8-1:0] line;
    int fp = $fopen(fname, "rb");
    if(fp==0) begin
        //$display("*** error: could not open file.");
        return -1;
    end
    linelen = $fgets(line, fp);
    if(line[8*(linelen-2)+:16] != 16'h5035) begin
        $display("*** error: the first line must be P5");
        $fclose(fp);
        return -1;
    end
    scanf_num = $fgets(line, fp);
    scanf_num = $sscanf(line, "%d%d", w, h);
    if(scanf_num == 1) begin
        scanf_num = $fgets(line, fp);
        scanf_num = $sscanf(line, "%d", h);
    end
    scanf_num = $fgets(line, fp);
    scanf_num = $sscanf(line, "%d", depth);
    if(depth < 1 || depth >= 65536) begin
        $display("*** error: images depth must be in range of 1~65535");
        $fclose(fp);
        return -1;
    end else if(depth < 256) begin
        byte_per_pixel = 1;
    end else begin
        byte_per_pixel = 2;
    end
    img = new[h];
    foreach(img[jj])
        img[jj] = new[w];
    for(int jj=0; jj<h; jj++) begin
        for(int ii=0; ii<w; ii++) begin
            img[jj][ii] = 0;
            for(int k=0; k<byte_per_pixel; k++) begin
                img[jj][ii] <<= 8;
                img[jj][ii] += $fgetc(fp);
            end
        end
    end
    $fclose(fp);
    return 0;
endfunction


// -------------------------------------------------------------------------------------------------------------------
//   task: feed image pixels to jls_encoder_i module
//   arguments:
//         img : input image array
//         w   : image width
//         h   : image height
//         bubble_control : bubble numbers that insert between pixels
//              when = 0, do not insert bubble
//              when > 0, insert bubble_control bubbles
//              when < 0, insert random 0~bubble_control bubbles
// -------------------------------------------------------------------------------------------------------------------
task automatic feed_img(input logic [15:0] img [][], input int w, input int h, input int bubble_control);
    int num_bubble, total_cycle;
    
    // start feeding a image by assert rstn for 50 cycles
    repeat(50) @(posedge clk) begin
        rstn <= 1'b0;
        i_w <= '0;
        i_h <= '0;
        i_e <= 1'b0;
        i_x <= '{5{'0}};
    end
    
    @(posedge clk) begin
        rstn <= 1'b1;
        i_w <= w - 1;
        i_h <= h - 1;
    end
    
    // for all pixels of the image
    for(int jj=0; jj<h; jj++) begin
        for(int ii=0; ii<w; ii++) begin
            
            // calculate how many bubbles to insert
            if(bubble_control<0) begin
                num_bubble = $random % (1-bubble_control);
                if(num_bubble<0)
                    num_bubble = -num_bubble;
            end else begin
                num_bubble = bubble_control;
            end
            
            // insert bubbles
            repeat(num_bubble) @(posedge clk) begin
                i_e <= '0;
                i_x <= '{5{'0}};
            end
            
            // assert i_e to input a pixel
            while(1) begin
                total_cycle++;
                @(posedge clk) begin
                    i_e <= 1'b1;
                    i_x <= '{img[jj][5*ii+0], img[jj][5*ii+1], img[jj][5*ii+2], img[jj][5*ii+3], img[jj][5*ii+4] };
                end
                @(negedge clk)
                    if(i_rdy)
                        break;
            end
        end
    end
    
    // 100 cycles idle between images
    repeat(100) @(posedge clk) begin
        i_e <= '0;
        i_x <= '{5{'0}};
    end
    
    $display("pixels=%d   cycles=%d   ppc=%f", 5*w*h, total_cycle, 5.0*w*h/total_cycle);
endtask


// -------------------------------------------------------------------------------------------------------------------
//   jls_encoder_i module
// -------------------------------------------------------------------------------------------------------------------
uh_jls uh_jls_i (
    .clk      ( clk            ),
    .rstn     ( rstn           ),
    .i_w      ( i_w            ),
    .i_h      ( i_h            ),
    .i_rdy    ( i_rdy          ),
    .i_e      ( i_e            ),
    .i_x      ( i_x            ),
    .o_e      ( o_e            ),
    .o_data   ( o_data         ),
    .o_last   ( o_last         )
);


int file_no;    // file number


// -------------------------------------------------------------------------------------------------------------------
//  read images, feed them to jls_encoder_i module 
// -------------------------------------------------------------------------------------------------------------------
initial begin
    logic [256*8:1] input_file_name;
    logic [256*8:1] input_file_format;
    $sformat(input_file_format , "%s\\%s.pgm",  `INPUT_PGM_DIR, `FILE_NAME_FORMAT);
    
    repeat (4) @ (posedge clk);

    for(file_no=0; file_no<=999; file_no++) begin
        int w, h;
        logic [15:0] img [][];

        $sformat(input_file_name, input_file_format , file_no);

        if( load_img(input_file_name, img, w, h) )         // file open failed
            continue;
        w /= 5;                                            // superscala width = 5
        
        $display("test%03d.pgm  (%5dx%5d)", file_no, 5*w, h);

        if( w < 1 || w > 2048 || h < 1 || h > 16383 )      // image size not supported
            $display("  *** image size not supported ***");
        else
            feed_img(img, w, h, `BUBBLE_CONTROL);
        
        foreach(img[jj])
            img[jj].delete();
        img.delete();
    end
    
    repeat(100) @(posedge clk);

    $stop;
end


// -------------------------------------------------------------------------------------------------------------------
//  write output stream to .jls files 
// -------------------------------------------------------------------------------------------------------------------
logic [256*8:1] output_file_format;
initial $sformat(output_file_format, "%s\\%s.jls", `OUTPUT_JLS_DIR, `FILE_NAME_FORMAT);
logic [256*8:1] output_file_name;
int opened = 0;
int jls_file = 0;

always @ (posedge clk)
    if(o_e) begin
        // the first data of an output stream, open a new file.
        if(opened == 0) begin
            opened = 1;
            $sformat(output_file_name, output_file_format, file_no);
            jls_file = $fopen(output_file_name , "wb");
        end
        
        // write data to file.
        if(opened != 0 && jls_file != 0)
            $fwrite(jls_file, "%c%c%c%c%c%c%c%c", o_data[7:0], o_data[15:8], o_data[23:16], o_data[31:24], o_data[39:32], o_data[47:40], o_data[55:48], o_data[63:56]);
        
        // if it is the last data of an output stream, close the file.
        if(o_last) begin
            opened = 0;
            $fclose(jls_file);
        end
    end

endmodule
