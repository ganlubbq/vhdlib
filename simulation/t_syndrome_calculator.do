vsim vhdlib_tb(syndrome_calculator_tb)
log -r /*
do t_syndrome_calculator_wave.do
run 300 ns
