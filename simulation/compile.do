vlib work
vcom -93 ../pkg/vhdlib_package.vhd
vcom -93 ../gf/gf_lookup_table.vhd
vcom -93 ../gf/gf_lookup_table_dp.vhd
vcom -93 ../crc/crc_generator_parallel.vhd
vcom -93 ../gf/gf_multiplier.vhd 
vcom -93 ../gf/gf_horner_multiplier.vhd 
vcom -93 ../gf/gf_horner_evaluator.vhd 
vcom -93 ../reed_solomon/decoder/syndrome_calculator.vhd 
vcom -93 ../reed_solomon/decoder/berlekamp_massey_calculator.vhd 
vcom -93 ../reed_solomon/decoder/error_value_evaluator.vhd 
vcom -93 ../reed_solomon/encoder/rs_lfsr_encoder.vhd 
vcom -93 ../reed_solomon/decoder/chien_search.vhd 
vcom -93 ../reed_solomon/decoder/forney_calculator.vhd 
vcom -93 ../prbs/prbs_generator_parallel.vhd 
vcom vhdlib_tb.vhd 
