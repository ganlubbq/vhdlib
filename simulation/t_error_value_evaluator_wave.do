onerror {resume}

quietly WaveActivateNextPane {} 0
add wave -noupdate /vhdlib_tb/dut/clk
add wave -noupdate /vhdlib_tb/dut/rst
add wave -noupdate /vhdlib_tb/dut/new_calc
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/syndromes_in
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/err_locator_in
add wave -noupdate /vhdlib_tb/dut/ready
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/err_eval_out
add wave -noupdate -radix unsigned /vhdlib_tb/dut/syndromes
add wave -noupdate -radix unsigned /vhdlib_tb/dut/err_locator
add wave -noupdate -radix unsigned /vhdlib_tb/dut/err_eval
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/mul_outputs
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/err_eval_coef
add wave -noupdate /vhdlib_tb/dut/calculator_state
add wave -noupdate /vhdlib_tb/dut/n
add wave -noupdate /vhdlib_tb/dut/shift_output

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

