![语言](https://img.shields.io/badge/语言-verilog_(IEEE1364_2001)-9A90FD.svg) ![仿真](https://img.shields.io/badge/仿真-iverilog-green.svg) ![部署](https://img.shields.io/badge/部署-quartus-blue.svg) ![部署](https://img.shields.io/badge/部署-vivado-FF1010.svg)

[English](#en) | [中文](#cn)

　

<span id="en">UH-JLS</span>
===========================

FPGA-based Ultra-High Throughput JPEG-LS image encoder.

* For lossless 8-bit grayscale images compression.
* Support image height range 1\~65536, width range 5\~10240, and the width must be a multiple of 5.
* Pixel-level parallelization using dynamic OoO scheduling. For natural images, the input throughput is about 4.5 pixels per clock cycle.

If you use this code, please cite:

> Xuan Wang, Lei Gong, Chao Wang, Xi Li, Xuehai Zhou : [UH-JLS: A Parallel Ultra-High Throughput JPEG-LS Encoding Architecture for Lossless Image Compression](https://ieeexplore.ieee.org/abstract/document/9643724). ICCD 2021: 335-343

### Stable Version

The stable version (in folder [RTL](./RTL))  is not clock-optimized, resulting in the clock frequency only reach 75 MHz on ZYNQ-7020.

### Development Version

The 185MHz development version is in folder [RTL_develop_ver](./RTL_develop_ver).  When I have time, I will standardize it to be the stable version.

### See Also

If you don't need high performance, you can use another repo of mine https://github.com/WangXuan95/FPGA-JPEG-LS-encoder . It is a JPEG-LS encoder based on scalar pipeline, with an input throughput of 1 pixel per cycle and supports lossy compression.

　

# Background

**JPEG-LS** (**JLS**) is a lossless/lossy image compression stardard. Its lossless compression ratio is better than PNG, Lossless-JPEG2000, Lossless-WEBP, and Lossless-HEIF. The file suffix for **JPEG-LS** compressed images is **.jls**.

JPEG-LS has two generations:

- JPEG-LS baseline (ITU-T T.87): JPEG-LS refers to the JPEG-LS baseline by default. **This repo implements the encoder of JPEG-LS baseline**. If you are interested in the software code of JPEG-LS baseline encoder, see https://github.com/WangXuan95/ImCvt (C++ language)
- JPEG-LS extension (ITU-T T.870): Its compression ratio is higher than JPEG-LS baseline, but it is very rarely (even no code can be found online). **This repo is not about JPEG-LS extension**. 

　

# How to use

[**RTL/uh_jls.v**](./RTL/uh_jls.v) is the JPEG-LS compression module for users, which inputs the original pixels of the image in line-scan order (left to right, top to bottom) and outputs JPEG-LS stream.

## Signal

**uh_jls** input and output signals list:

|Signal name| Full name | direction | width | description |
| :---: | :---: | :---: | :---: | :--- |
| clk | clock | input | 1bit |Clock, all signals should be synchronized to the rising edge of clk|
|   i_sof   |   start of frame   | input  |  1bit  |Before inputting a new image, i_sof should keep 1 for at least 50 cycles|
| i_w | width | input | 11bit |Image width = 5*(i_w+1), where i_w ∈ [0, 2047], i.e., width = 5, 10, 15.. 10240|
| i_h | height | input | 16bit |Image height = i_h+1, where i_h ∈ [0, 65535], i.e.: height ∈ [1, 65536]|
| i_rdy | input ready | output | 1bit |When i_rdy=1, the module is ready to accept input pixels.|
| i_e | input enable | input | 1bit |When i_e=1, user is inputting pixels to the module, and i_x0\~4 should be valid.|
| i_x0 | input pixel0 | input | 8bit |Parallel input pixel0|
| i_x1 | input pixel1 | input | 8bit |Parallel input pixel1|
| i_x2 | input pixel2 | input | 8bit |Parallel input pixel2|
| i_x3 | input pixel3 | input | 8bit |Parallel input pixel3|
| i_x4 | input pixel4 | input | 8bit |Parallel input pixel4|
| o_e | output enable | output | 1bit |When o_e=1, o_data is valid|
| o_data | output data | output | 64bit |JPEG-LS output stream data, 8 bytes in little-endian.|
| o_last | output stream last | output | 1bit |When o_e=1 and o_last=1, current data is the last data of a stream.|

> Example for i_w and i_h : if the input image is 1920x1080, then i_w = 1920/5-1 = 11'd383; i_h = 1080-1 = 16'd1079.

## Input pixels

The operation steps of uh_jls is :

1. **Preparation**: Before starting to input images, let i_sof=1 at least **50 cycles**. After that set i_sof=0. When i_sof=1, you should keep i_w and i_h valid to specify the width and height of the image.
2. **Input**: control i_e and i_x0\~i_x4 to input all pixels of this image from left to right, top to bottom. Note that:
   1. The module needs to input adjacent 5 pixels in parallel at a time, placed on i_x0\~i_x4 from left to right.
   2.  i_e and i_rdyform a pair of handshaking signals, when i_e=1, i_x0\~i_x4 should be valid, meanwhile, if i_rdy=1, the current five pixels are successfully inputted, and in the next period, i_x0\~i_x4 will input the subsequent five pixels; If i_rdy=0, it means that the current input is blocked, and i_e, i_x0\~i_x4 should remain unchanged in the next cycle.

3. **Idle between images**: After all the pixels of an image are inputted, it is necessary to be idle for **at least 500 cycles** (keep both i_e and i_sof =0). Then you can jump to step1 and prepare to enter the next image.

## Output JPEG-LS stream

During inputting, **uh_jls** will output **JPEG-LS stream** simultaneously, which constitutes the data of a .jls file (including the file header and footer). When o_e=1, a valid output data is generated on o_data. Note that o_data is in **Little endian**, i.e., o_data[7:0] is located at the front of the stream and o_data[63:56] is located at the back of the stream. If the currently output data is the last data in the output stream of an image, o_last=1. Otherwise, o_last=0.

　

# Simulation

This repo provides a testbench, which can read out the pixels in .pgm image in the specified folder, send them to **uh_jls** to compress, and then save the output results of **uh_jls** to .jls files.

### Simulation related files

* [SIM/tb_uh_jls.v](./SIM/tb_uh_jls.v) Is the top level of  simulation.
* [SIM/tb_load_and_feed_image.v](./SIM/tb_load_and_feed_image.v) is responsible for reading raw pixels from .pgm image files.
* [SIM/tb_iverilog.bat](./SIM/tb_iverilog.bat) Is the script to run iverilog simulation.
* [SIM/images](./SIM/images) Is the input folder for the simulation and contains some 8-bit grayscale images in .pgm format.

### Simulation step

iverilog simulation steps:

- Install iverilog, see: [iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)
- Double-click tb_iverilog.bat to run simulation (for Windows only), For the images I provided, the simulation will take about 2 hours to run.
- After simulation, the compressed .jls file will appears in **SIM** folder.

### Other instructions

.pgm format is an uncompressed image file format that can be viewed using [this webpage](https://filext.com/file-extension/PGM).

.jls file can be viewed with [this webpage](https://filext.com/file-extension/JLS).

Modifying the macro **BUBBLE_CONTROL** in tb_load_and_feed_image.v can determine how many bubbles are inserted between adjacent pixels (bubbles refer to the number of idle cycles after a pixel is successfully input before the next pixel is input):

- When **BUBBLE_CONTROL=0**, no bubble will be inserted (getting the highest input rate).
- When **BUBBLE_CONTROL>0** , insert **BUBBLE_CONTROL** bubbles each time.
- When **BUBBLE_CONTROL<0**, random **0~(-BUBBLE_CONTROL)** bubbles are inserted each time.

You can add more .pgm files to **images** folder for simulation. The file names must be in the form of testXXX.pgm, where XXX are a three digit numbers.

　

　

　

　

　



<span id="cn">UH-JLS</span>
===========================

基于 **FPGA** 的高性能 **JPEG-LS** 图像压缩器

* 使用 Verilog 编写。
* 用于无损压缩 **8bit** 的灰度图像。
* 图像高度取值范围为 1\~65536 ，宽度取值范围为 5\~10240，宽度必须是 5 的倍数。
* 使用动态乱序调度进行像素级并行。对于自然图像，输入吞吐率约为 4.5 个像素每时钟周期。

本工程来自以下论文。如果你用到了本代码，请引用：

> Xuan Wang, Lei Gong, Chao Wang, Xi Li, Xuehai Zhou : [UH-JLS: A Parallel Ultra-High Throughput JPEG-LS Encoding Architecture for Lossless Image Compression](https://ieeexplore.ieee.org/abstract/document/9643724). ICCD 2021: 335-343

### 稳定版本

稳定版本在 [RTL](./RTL) 目录下，它的 Verilog 编码较为规范，但没有优化 JPEG-LS 的 run-mode 下计算 run-length 的电路，导致时钟频率在 ZYNQ-7020 上的频率只能达到 75 MHz 。

### 开发版本

开发版本在 [RTL_develop_ver](./RTL_develop_ver) 目录下，频率在 ZYNQ-7020 上可以达到 185MHz。但是这个版本当前只有论文中所属的 "Pseudo-LS" 模式，是轻微有损的（而不是无损的），将来我会把这个版本修改为支持无损的，并作为正式版本。

### 你还可以看看

如果你对性能要求不高，可以使用我的另一个库： https://github.com/WangXuan95/FPGA-JPEG-LS-encoder ，它是基于标量流水线的 JPEG-LS encoder ，输入吞吐率为 1 个像素每周期，而且支持有损压缩。

　

# 背景知识

**JPEG-LS** （简称**JLS**）是一种无损/有损的图像压缩算法，其无损模式的压缩率相当优异，优于 PNG、Lossless-JPEG2000、Lossless-WEBP、Lossless-HEIF 等。**JPEG-LS** 压缩图像的文件后缀是 .**jls** 。

JPEG-LS 有两代：

- JPEG-LS baseline (ITU-T T.87) : 一般提到 JPEG-LS 默认都是指 JPEG-LS baseline。**本库也实现的是 JPEG-LS baseline 的 encoder** 。如果你对软件版本的 JPEG-LS baseline encoder 感兴趣，可以看 https://github.com/WangXuan95/ImCvt (C++实现)
- JPEG-LS extension (ITU-T T.870) : 其压缩率高于 JPEG-LS baseline ，但使用的非常少 (在网上搜不到任何代码) 。 **本库与 JPEG-LS extension 无关！** 

　

# 使用方法

[**RTL/uh_jls.v**](./RTL/uh_jls.v) 是用户可以调用的 JPEG-LS 压缩模块，它按行扫描 (从左到右，从上到下) 的顺序输入图像原始像素，输出 .**jls** 文件的内容。

## 信号

**uh_jls** 的输入输出信号描述如下表。

| 信号名称 | 全称 | 方向 | 宽度 | 描述 |
| :---: | :---: | :---: | :---: | :--- |
| clk | 时钟 | input | 1bit | 时钟，所有信号都应该与 clk 上升沿同步 |
|   i_sof   |   图像开始   | input  |  1bit  | 当需要输入一个新的图像时，保持至少50个时钟周期的 i_sof=1 |
| i_w | 图像宽度参数 | input | 11bit | 图像宽度 = 5*(i_w+1) ，其中 i_w∈[0,2047]，也即：width=5,10,15...10240 |
| i_h | 图像高度参数 | input | 16bit | 图像高度= i_h+1 ，其中 i_h∈[0,65535]，也即：height∈[1,65536] |
| i_rdy | 输入像素允许 | output | 1bit | i_rdy=1时，说明模块已经准备好接受输入像素，与 i_en 构成握手信号。 |
| i_e | 输入像素有效 | input | 1bit | i_e=1 时，外界已经准备好发送像素给模块，同时 i_x0\~4 应该有效。 |
| i_x0 | 输入像素1 | input | 8bit | 并行输入横向的相邻的5个像素中的第1个 |
| i_x1 | 输入像素2 | input | 8bit | 并行输入横向的相邻的5个像素中的第2个 |
| i_x2 | 输入像素3 | input | 8bit | 并行输入横向的相邻的5个像素中的第3个 |
| i_x3 | 输入像素4 | input | 8bit | 并行输入横向的相邻的5个像素中的第4个 |
| i_x4 | 输入像素5 | input | 8bit | 并行输入横向的相邻的5个像素中的第5个 |
| o_e | 输出有效    | output | 1bit | 当 o_e=1 时，输出流数据产生在 o_data 上。 |
| o_data | 输出流数据 | output | 64bit | JPEG-LS 输出流，8 字节按小端序排布。 |
| o_last | 输出流末尾 | output | 1bit | 当 o_e=1 时若 o_last=1 ，说明这是一张图像的输出流的最后一个数据。 |

> 对 i_w 和 i_h 的举例：若输入图片为 1920x1080，则 i_w = 1920/5-1 = 11'd383；i_h = 1080-1 = 16'd1079。

## 输入像素

**uh_jls 模块**的操作的流程是：

1. **准备**：开始输入图像前，令 i_sof=1 至少 **50 个周期**。50个周期后让 i_sof 恢复 0。在 i_sof=1 期间，要让 i_w 和 i_h 保持有效，指定该图像的宽和高。
2. **输入**：控制 i_e 和 i_x0\~i_x4，从左到右，从上到下地输入该图像的所有像素。注意：
   1. 该模块每次需要并行输入横向相邻的 5 个像素，从左到右分别放在 i_x0\~i_x4 上。
   2.  i_e 和 i_rdy 构成握手信号，当 i_e=1 时，i_x0\~i_x4 应该有效，同时如果 i_rdy=1 ，当前像素成功输入，下个周期 i_x0\~i_x4 就要输入后继的5个像素；如果 i_rdy=0，代表当前输入被阻塞，下个周期 i_x0\~i_x4 就要保持不变。

3. **图像间空闲**：一张图像所有像素输入结束后，需要空闲**至少 500 个周期**不做任何动作 (i_sof 和 i_e 都保持 0)。然后才能跳到第1步，准备输入下一个图像。

## 输出压缩流

在输入过程中，**uh_jls** 同时会输出压缩好的 **JPEG-LS流**，该流构成了完整的 .jls 文件的内容 (包括文件头和尾)。o_e=1 时，o_data 上产生一个有效输出数据。o_data 宽度是 64bit，也即 8字节，遵循**小端序**，即 o_data[7:0] 在流中的位置最靠前，o_data[63:56] 在流中的位置最靠后。如果当前输出的数据是一张图像的输出流中的最后一个数据，则 o_last=1 。其它情况下 o_last=0 。

　

# 仿真

本库提供一个 testbench ，可以将指定文件夹里的 .pgm 格式的图像中的像素读出，送入 **uh_jls** 进行压缩，然后将 **uh_jls** 的输出结果保存到 .jls 文件里。

### 仿真相关文件

* [SIM/tb_uh_jls.v](./SIM/tb_uh_jls.v) 是仿真顶层。它调用 **uh_jls.v** 进行仿真。
* [SIM/tb_load_and_feed_image.v](./SIM/tb_load_and_feed_image.v) 负责从 .pgm 图像文件中读取原始像素，该模块会被 tb_uh_jls.v 调用。
* [SIM/tb_iverilog.bat](./SIM/tb_iverilog.bat) 是运行 iverilog 仿真的脚本。
* [SIM/images](./SIM/images) 是仿真的输入文件夹，包含一些 .pgm 格式的 8bit 灰度图。

### 仿真步骤

用 iverilog 仿真器进行行为仿真。步骤如下：

- 安装 iverilog ，见：[iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)
- 双击 tb_iverilog.bat 运行仿真 (仅限Windows)，压缩完所有图像后它会遇到 `$finish;` 而停止，对于我提供的这些图像，仿真大约需要运行2个小时。
- 仿真结束，**SIM** 文件夹里出现压缩后的 .jls 文件。

### 其它说明

.pgm 格式是一种未压缩的图像文件格式，可以使用 photoshop 等软件或[该网页](https://filext.com/file-extension/PGM)来查看。

.pgm 文件有一个简单的文件头格式， tb_load_and_feed_image.v 里的 load_img 函数解析该格式，读出图像的宽和高，并把它的所有像素放在 img 数组里。总之，你可以不关注 .pgm 的格式，重点关注仿真波形，关注如何操作 **uh_jls** 的时序。

.jls 文件可以用[该网站](https://filext.com/file-extension/JLS)查看。

修改 tb_load_and_feed_image.v 里的宏名 **BUBBLE_CONTROL** 可以决定相邻像素间插入多少个气泡 (气泡是指成功输入一个像素后，再空闲多少个周期才输入下一个像素) ：

- **BUBBLE_CONTROL=0** 时，不插入任何气泡 (最高输入速率) 。
- **BUBBLE_CONTROL>0** 时，插入 **BUBBLE_CONTROL** 个气泡。
- **BUBBLE_CONTROL<0** 时，每次插入随机的 **0~(-BUBBLE_CONTROL)** 个气泡

你可以往 **images** 文件夹中放入其它的 .pgm 文件来压缩，文件名必须形如 testXXX.pgm (XXX 是三个数字) 。





