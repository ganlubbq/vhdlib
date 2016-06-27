vsim vhdlib_tb(prbs_generator_parallel_tb)
log -r /*
do t_prbs_generator_parallel_wave.do
run 110 ns
