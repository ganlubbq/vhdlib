onerror {resume}

quietly WaveActivateNextPane {} 0
add wave -noupdate -radix unsigned /vhdlib_tb/dut/coefficient
add wave -noupdate -radix unsigned /vhdlib_tb/dut/evaluation_value
add wave -noupdate -radix unsigned /vhdlib_tb/dut/product_in
add wave -noupdate -radix unsigned /vhdlib_tb/dut/product_out

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

