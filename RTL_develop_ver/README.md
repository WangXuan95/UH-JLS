
This is a development version that can reach a frequency of 185MHz.

It currently only supports the "Pseudo-LS" manner described in the paper [1], so it is slightly lossy (rather than lossless).

It have no known functional bugs, but the code is written in SystemVerilog (not Verilog) and is not very standardized.

When I have time, I will modify it to both "Lossless" manner and "Pseudo-LS" manner, and let it be the stable version.

　

[1] Xuan Wang, Lei Gong, Chao Wang, Xi Li, Xuehai Zhou : [UH-JLS: A Parallel Ultra-High Throughput JPEG-LS Encoding Architecture for Lossless Image Compression](https://ieeexplore.ieee.org/abstract/document/9643724). ICCD 2021: 335-343
