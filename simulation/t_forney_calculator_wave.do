onerror {resume}

add log -r sim:/vhdlib_tb/dut/*

quietly WaveActivateNextPane {} 0
add wave -noupdate /vhdlib_tb/dut/clock
add wave -noupdate /vhdlib_tb/dut/clock_enable
add wave -noupdate /vhdlib_tb/dut/reset
add wave -noupdate /vhdlib_tb/dut/new_calculation
add wave -noupdate /vhdlib_tb/dut/ready
add wave -noupdate /vhdlib_tb/dut/new_numerator_calculation
add wave -noupdate /vhdlib_tb/dut/error_eval_shift_count
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/term_product
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_roots
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_evaluator
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_values
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_roots_registers  
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_evaluator_registers
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_eval_coefficients
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/numerator_values
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/numerator_values_latch
add wave -noupdate /vhdlib_tb/dut/state

TreeUpdate [SetDefaultTree]

configure wave -namecolwidth 236
configure wave -valuecolwidth 115
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

update

