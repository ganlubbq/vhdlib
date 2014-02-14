vsim vhdlib_tb(gf_horner_evaluator_tb)
log -r /*
do t_gf_horner_evaluator_wave.do
run 300 ns
