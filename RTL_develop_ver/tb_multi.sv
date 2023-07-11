`timescale 1ns/1ps

`define WIDTH      256
`define HEIGHT     256

`define START_INDEX 1
`define FINAL_INDEX 50

`define PGM_FILE_NAME_FORMAT "E:\\FPGAcommon\\UH-JLS\\ds_UCIDv2\\ucid%05d.pgm"

`define OUT_ENABLE 1
`define JLS_FILE_NAME_FORMAT "E:\\FPGAcommon\\UH-JLS\\ds_UCIDv2_jls\\ucid%05d.jls"

`define LOG_ENABLE 0
`define LOG_FILE_NAME_FORMAT "E:\\FPGAcommon\\UH-JLS\\ds_UCIDv2_log\\ucid%05d.txt"

`define CLK_PERIOD 4

module tb_multi();

// -------------------------------------------------------------------------------------------------------------------
//   function: load image to 2-D array from PGM file
// -------------------------------------------------------------------------------------------------------------------
function automatic logic load_img(input logic [256*8:1] fname, ref [7:0] img [0:(`HEIGHT)][0:(`WIDTH+1)]);
    int linelen, width, height, depth, rbyte, trash;
    logic [256*8-1:0] line;
    int fp = $fopen(fname, "rb");
    if(fp==0) begin
        $write("*** error: could not open file.\n");
        return 1'b0;
    end
    linelen = $fgets(line, fp);
    if(line[8*(linelen-2)+:16]!=16'h5035) begin
        $write("*** error: the first line must be P5\n");
        $fclose(fp);
        return 1'b0;
    end
    trash = $fgets(line, fp);
    trash = $sscanf(line, "%d%d", width, height);
    trash = $fgets(line, fp);
    trash = $sscanf(line, "%d", depth);
    if(depth!=255) begin
        $write("*** error: images depth must be 255\n");
        $fclose(fp);
        return 1'b0;
    end
    foreach(img[i,j])
        img[i][j] = 8'h0;
    for(int i=1; i<=height; i++) begin
        for(int j=1; j<=width; j++) begin
            rbyte = $fgetc(fp);
            if(i<=`HEIGHT && j<=`WIDTH)
                img[i][j] = rbyte[7:0];
        end
    end
    foreach(img[ii,jj]) begin
        if(ii==0) begin
            img[ii][jj] = 8'h00;
        end else if(jj==0) begin
            img[ii][jj] = img[ii-1][jj+1];
        end else if(jj==$high(img,2)) begin
            img[ii][jj] = img[ii][jj-1];
        end
    end
    $fclose(fp);
    return 1'b1;
endfunction

// -------------------------------------------------------------------------------------------------------------------
//   function: write byte array to binary file
// -------------------------------------------------------------------------------------------------------------------
function automatic void write_array_to_file(input logic [256*8:1] fname, ref [7:0] array [2*`HEIGHT*`WIDTH], input int length);
    automatic int fp = $fopen(fname , "wb");
    for(int i=0; i<length; i++) begin
        $fwrite(fp, "%c", array[i]);
    end
    $fclose(fp);
endfunction

// -------------------------------------------------------------------------------------------------------------------
//   function: write byte array to txt log file
// -------------------------------------------------------------------------------------------------------------------
function automatic void write_array_to_log(input logic [256*8:1] fname, ref [7:0] array [2*`HEIGHT*`WIDTH], input int length);
    automatic int fp = $fopen(fname , "w");
    for(int i=0; i<length; i++) begin
        $fwrite(fp, "%02x ", array[i]);
    end
    $fclose(fp);
endfunction

// output JLS stream (byte array)
reg  [ 7:0] jls_array [2*`HEIGHT*`WIDTH];  // output JLS stream (byte array)
int         jls_array_ptr = 0;             // byte pointer for jls_array
reg  [ 2:0] jls_array_bit_ptr = 3'd7;      // bit pointer  for jls_array

// clock and reset
reg       clk=1'b0;
reg       rst=1'b1;
always #(`CLK_PERIOD/2) clk = ~clk;   // generate clock

// uh_jls input signals
reg         ena = 1'b0;
wire        rdy;
reg  [ 7:0] i_x [1:8] = '{8{8'h0}};

// uh_jls output signals
wire        o_vl;
wire[191:0] o_bv;
wire [ 7:0] o_bc;

// -------------------------------------------------------------------------------------------------------------------
//  main simulation program
// -------------------------------------------------------------------------------------------------------------------
initial begin
    // file name
    automatic logic [256*8:1] pgm_fname, jls_fname, log_fname;
    
    // array from PGM files
    automatic logic    [ 7:0] img_array [0:(`HEIGHT)][0:(`WIDTH+1)];
    
    // width and height bytes for writing JLS stream
    automatic logic  [ 7:0] HEIGHT_H = `HEIGHT / 256;
    automatic logic  [ 7:0] HEIGHT_L = `HEIGHT % 256;
    automatic logic  [ 7:0]  WIDTH_H = `WIDTH  / 256;
    automatic logic  [ 7:0]  WIDTH_L = `WIDTH  % 256;
    
    automatic int total_count = 0;
    automatic int total_jls_size = 0;
    automatic int total_cycles = 0;

    for(int file_index=`START_INDEX; file_index<=`FINAL_INDEX; file_index++) begin
    
        // cycle count, for calculating performance.
        automatic int cycles = 0;
    
        $sformat(pgm_fname, `PGM_FILE_NAME_FORMAT, file_index);
        $sformat(jls_fname, `JLS_FILE_NAME_FORMAT, file_index);
        $sformat(log_fname, `LOG_FILE_NAME_FORMAT, file_index);
        
        $write("Origin PGM file name: %s\n", pgm_fname);
    
        // set JLS stream head
        jls_array[0:25] = '{8'hFF, 8'hD8, 8'hFF, 8'hF7, 8'h00, 8'h0B, 8'h08, HEIGHT_H, HEIGHT_L, WIDTH_H, WIDTH_L, 8'h01, 8'h01, 8'h11, 8'h00, 8'hFF, 8'hDA, 8'h00, 8'h08, 8'h01, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
        jls_array_ptr = 25;
        jls_array_bit_ptr = 3'd7;
        
        // load image from PGM file to img_array (2-D array)
        if( ~load_img(pgm_fname, img_array) )
            continue;

        // delay and release the reset signal
        repeat(4) @(posedge clk);
        rst <= 1'b1;
        repeat(4) @(posedge clk);
        rst <= 1'b0;

        // feed img_array (2-D array) to uh_jls module
        for(int ii=$low(img_array,1)+1; ii<=$high(img_array,1); ii++) begin
            for(int jj=$low(img_array,2); jj<$high(img_array,2)-1; jj+=8) begin
                @(posedge clk) ena <= 1'b1; cycles++;
                while(~rdy) @(posedge clk) cycles++;
                for(int kk=1; kk<=8; kk++) begin
                    i_x[kk] <= img_array[ii][jj+kk];
                end
            end
        end
        
        // delay
        repeat(60) @(posedge clk);
        ena <= 1'b0;
        repeat(60) @(posedge clk);
        
        // flush last byte, if necessary
        if(jls_array_bit_ptr!=3'd7)
            jls_array_ptr++;
        
        // set the end symbol in JLS stream
        jls_array[jls_array_ptr++] = 8'hFF;
        jls_array[jls_array_ptr++] = 8'hD9;
        
        // print statistic info
        $write("  Origin size=%.0f   JLS size=%.0f   Compression ratio=%.2f\n", 1.0*`WIDTH*`HEIGHT, 1.0*jls_array_ptr, 1.0*`WIDTH*`HEIGHT/jls_array_ptr);
        $write("  Clock freq=%.2fMHz   Cycles elapsed=%.0f   PixelperCycle=%.2f   Throughput=%.2fMBps\n", 1000.0/`CLK_PERIOD, 1.0*cycles, 1.0*`WIDTH*`HEIGHT/cycles, 1000.0*`WIDTH*`HEIGHT/`CLK_PERIOD/cycles);
        
        total_count++;
        total_jls_size += jls_array_ptr;
        total_cycles += cycles;
        
        // write JLS byte array to JLS file
        if(`OUT_ENABLE)
            write_array_to_file(jls_fname, jls_array, jls_array_ptr);
        
        // write JLS byte array to TXT LOG file
        if(`LOG_ENABLE)
            write_array_to_log(log_fname, jls_array, jls_array_ptr);
    
    end
    
    $write("Total statistics for %6d images:\n", total_count);
    $write("  Origin size=%.0f   JLS size=%.0f   Compression ratio=%.2f\n", 1.0*total_count*`WIDTH*`HEIGHT, 1.0*total_jls_size, 1.0*total_count*`WIDTH*`HEIGHT/total_jls_size);
    $write("  Clock freq=%.2fMHz   Cycles elapsed=%.0f   PixelperCycle=%.2f   Throughput=%.2fMBps\n", 1000.0/`CLK_PERIOD, 1.0*total_cycles, 1.0*total_count*`WIDTH*`HEIGHT/total_cycles, 1000.0*total_count*`WIDTH*`HEIGHT/`CLK_PERIOD/total_cycles);
    
    $stop;
end


// -------------------------------------------------------------------------------------------------------------------
//  using the output of uh_jls to write the jls stream array
// -------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(o_vl) begin
        for(logic [7:0] ii=8'd0; ii<o_bc; ii++) begin
            jls_array[jls_array_ptr][jls_array_bit_ptr] = o_bv[8'd191-ii];
            jls_array_bit_ptr--;
            if(jls_array_bit_ptr==3'd7) begin
                if(jls_array[jls_array_ptr]==8'hff)
                    jls_array_bit_ptr--;
                jls_array_ptr++;
                jls_array[jls_array_ptr] = 8'h00;
            end
        end
    end

// -------------------------------------------------------------------------------------------------------------------
//  uh_jls instance
// -------------------------------------------------------------------------------------------------------------------
uh_jls uh_jls_i(
    .rst      ( rst            ),
    .clk      ( clk            ),
    .width    ( `WIDTH / 8 - 1 ),
    .height   ( `HEIGHT        ),
    .ena      ( ena            ),
    .stall_n  ( rdy            ),
    .i_x      ( i_x            ),
    .o_vl     ( o_vl           ),
    .o_bv     ( o_bv           ),
    .o_bc     ( o_bc           )
);

endmodule
