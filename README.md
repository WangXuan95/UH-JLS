UH-JLS
===========================
FPGA-based Ultra-High Throughput JPEG-LS image encoder.

基于 **FPGA** 的 **JPEG-LS** 图象压缩器（超标量高性能版）

* 可无损压缩 **8bit** 的灰度图像。
* 图像宽度取值范围为[5,10240]，且必须是5的倍数；高度取值范围为[1,65536]。
* 使用 **SystemVerilog** 编写。



# 背景知识

**JPEG-LS** （简称**JLS**）是一种无损/有损的图像压缩算法，其无损模式的压缩率相当优异，优于 Lossless-JPEG、Lossless-JPEG2000、Lossless-JPEG-XR、FELICES 等。**JPEG-LS** 压缩图像的文件后缀是 .**jls** 。



# 使用方法

[**RTL/uh_jls.sv**](./RTL/uh_jls.sv) 是用户可以调用的 JPEG-LS 压缩模块，它按行扫描（从左到右，从上到下）的顺序输入图像原始像素，输出 .**jls** 文件的内容。

## 信号

**uh_jls** 的输入输出信号描述如下表。

| 信号名称 | 全称 | 方向 | 宽度 | 描述 |
| :---: | :---: | :---: | :---: | :--- |
| clk | 时钟 | input | 1bit | 时钟，所有信号都应该与 clk 上升沿同步 |
|   rstn   |   同步复位   | input  |  1bit  | 输入每张图像前，令rstn=0进行复位，输入图像时，令rstn=1       |
| i_w | 图像宽度参数 | input | 11bit | 图像宽度 = 5*(i_w+1) ，其中 i_w∈[0,2047]，也即：width=5,10,15...10240 |
| i_h | 图像高度参数 | input | 16bit | 图像高度= i_h+1 ，其中 i_h∈[0,65535]，也即：height∈[1,65536] |
| i_rdy | 输入像素允许 | output | 1bit | i_rdy=1时，说明模块已经准备好接受输入像素，与 i_en 构成握手信号。 |
| i_e | 输入像素有效 | input | 1bit | i_e=1 时，外界已经准备好发送像素给模块，同时 i_x 应该有效。 |
| i_x | 5个输入像素  | input | 8bit*5 | 并行输入横向的相邻的5个像素，i_x[0]是最左像素，i_x[4]是最右像素。 |
| o_e | 输出有效    | output | 1bit | 当 o_e=1 时，输出流数据产生在 o_data 上。 |
| o_data | 输出流数据 | output | 64bit | JPEG-LS 输出流，8 字节按小端序排布。 |
| o_last | 输出流末尾 | output | 1bit | 当 o_e=1 时若 o_last=1 ，说明这是一张图象的输出流的最后一个数据。 |

> 对 i_w 和 i_h 的举例：若输入图片为 1920x1080，则 i_w = 1920/5-1 = 11'd383；i_h = 1080-1 = 16'd1079。

## 输入像素

**uh_jls 模块**的操作的流程是：

1. **复位**：开始输入图像前，令 rstn=0 至少 **50 个周期**进行复位。
3. **输入**：令 rstn=1 ，同时保持 i_w 和 i_h 有效。同时控制 i_e 和 i_x，从左到右，从上到下地输入该图像的所有像素。注意 i_e 和 i_rdy 构成握手信号，当 i_e=1 时，i_x 应该有效，同时如果 i_rdy=1 ，该像素成功输入，下个周期 i_x 就要输入后继的5个像素；如果 i_rdy=0，代表当前输入被阻塞，下个周期 i_x 就要保持当前5个像素不变。
4. **图像间空闲**：所有像素输入结束后，需要空闲**至少 100 个周期**不做任何动作（rstn保持1, i_w, i_h保持不变, i_e=0）。然后才能跳到第1步，复位并开始输入下一个图像。

## 输出压缩流

在输入过程中，**uh_jls** 同时会输出压缩好的 **JPEG-LS流**，该流构成了完整的 .jls 文件的内容（包括文件头部和尾部）。o_e=1 时，o_data 上产生一个有效输出数据。o_data 宽度是 64bit（8字节），遵循小端序，即 o_data[7:0] 在流中的位置最靠前，o_data[63:56] 在流中的位置最靠后。在每个图像的输出流遇到最后一个数据时，o_last=1 指示一张图像的压缩流结束。



# 仿真

本库提供一个仿真（testbench）代码，可以将指定文件夹里的 .pgm 格式的未压缩图像中的像素读出，批量送入 **uh_jls** 进行压缩，然后将 **uh_jls** 的输出结果保存到 .jls 文件里。

## 仿真相关文件

* [**RTL/tb_uh_jls.sv**](./RTL/tb_uh_jls.sv) 是仿真代码。它调用 **uh_jls.sv** 进行仿真。
* **images** 是仿真的输入文件夹，包含一些 .pgm 格式的 8bit 灰度图。 .pgm 格式存储的是未压缩的原始像素，可以使用 photoshop 等软件或[该网页](https://filext.com/file-extension/PGM)来查看。
* **images_jls** 是仿真的输出文件夹，用于存放仿真输出的 .jls 压缩图像文件。.jls 文件可以用[该网站](https://filext.com/file-extension/JLS)查看。

## 仿真步骤

用 Vivado 进行行为仿真。步骤如下：

- 建立 Vivado 工程，将 **RTL** 文件夹中的所有 .sv 文件加入工程。以 tb_uh_jls 模块为仿真顶层。
- 将 tb_uh_jls.sv 里的宏名 **INPUT_PGM_DIR** 改成你的计算机里的 **images** 文件夹（即输入文件夹）的路径。注意！Windows下的目录分隔符为\\（单反斜杠），但因为 Verilog 字符串需要转义，所以这里的分隔符是\\\\（双反斜杠）。
- 将 tb_uh_jls.sv 里的宏名 **OUTPUT_JLS_DIR** 改成你的计算机里 **images_jls** 文件夹（即输出文件夹）的路径。
- 运行仿真，运行时间可以设置的很长（比如1000s），压缩完所有图像后它会遇到 $stop; 而停止。
- 仿真结束，**images_jls** 文件夹里出现压缩后的 .jls 文件。

.pgm 文件有一个简单的文件头格式， tb_uh_jls.sv 里的 load_img 函数解析该格式，读出图像的宽和高，并把它的所有像素放在 img 数组里。总之，你可以不关注 .pgm 的格式，重点关注仿真波形，关注如何操作 **uh_jls** 的时序。

修改 tb_uh_jls.sv 里的宏名 **BUBBLE_CONTROL** 可以决定相邻像素间插入多少个气泡（气泡是指成功输入一个像素后，再空闲多少个周期才输入下一个像素）：

- **BUBBLE_CONTROL=0** 时，不插入任何气泡（最高输入速率）。
- **BUBBLE_CONTROL>0** 时，插入 **BUBBLE_CONTROL **个气泡。
- **BUBBLE_CONTROL<0** 时，每次插入随机的 **0~(-BUBBLE_CONTROL)** 个气泡

你可以往 **images** 文件夹中放入其它的 .pgm 文件来压缩，文件名必须形如 testXXX.pgm （XXX 是三个数字）。



# 相关链接

标量版 FPGA JPEG-LS 图像压缩器，性能远低于本库，但支持有损 JPEG-LS，且更易使用：

https://github.com/WangXuan95/Hard-JPEG-LS



