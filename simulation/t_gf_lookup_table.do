vsim vhdlib_tb(gf_lookup_table_tb)
log -r /*
do t_gf_lookup_table_wave.do
run 300 ns
