del sim.out dump.vcd
iverilog  -g2001  -o sim.out  tb_uh_jls.v  tb_load_and_feed_image.v  ../RTL/*.v
vvp -n sim.out
del sim.out
pause