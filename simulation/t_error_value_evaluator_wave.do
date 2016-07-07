onerror {resume}

quietly WaveActivateNextPane {} 0
add wave -noupdate /vhdlib_tb/dut/clock
add wave -noupdate /vhdlib_tb/dut/reset
add wave -noupdate /vhdlib_tb/dut/new_calculation
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/syndromes
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_locator
add wave -noupdate /vhdlib_tb/dut/ready
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_evaluator
add wave -noupdate -radix unsigned /vhdlib_tb/dut/syndromes
add wave -noupdate -radix unsigned /vhdlib_tb/dut/error_locator_registers
add wave -noupdate -radix unsigned /vhdlib_tb/dut/error_evaluator_registers
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/multiplier_outputs
add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/error_evaluator_coefficient
add wave -noupdate /vhdlib_tb/dut/state
add wave -noupdate /vhdlib_tb/dut/n

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

