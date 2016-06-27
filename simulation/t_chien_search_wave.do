onerror {resume}

quietly WaveActivateNextPane {} 0
add wave -noupdate /vhdlib_tb/dut/clock
add wave -noupdate /vhdlib_tb/dut/reset
add wave -noupdate /vhdlib_tb/dut/new_calculation
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_locator_in
add wave -noupdate /vhdlib_tb/dut/ready
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_roots_out
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_locations_out
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gammas
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gammas_new
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gammas_sum
add wave -noupdate /vhdlib_tb/dut/calculator_state
add wave -noupdate -radix unsigned /vhdlib_tb/dut/i
add wave -noupdate /vhdlib_tb/dut/k
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gf_element_exp_in
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gf_element_inv_in
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gf_element_exp_out
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gf_element_inv_out
add wave -noupdate -radix unsigned /vhdlib_tb/dut/error_roots
add wave -noupdate -radix unsigned /vhdlib_tb/dut/error_locations
add wave -noupdate -radix unsigned /vhdlib_tb/dut/error_symbol_locations
add wave -noupdate /vhdlib_tb/dut/root_found

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

