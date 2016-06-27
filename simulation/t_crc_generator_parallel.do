vsim vhdlib_tb(crc_generator_parallel_tb)
log -r /*
do t_crc_generator_parallel_wave.do
run 50 ns
