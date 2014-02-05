onerror {resume}

quietly WaveActivateNextPane {} 0
# add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/prbs_in
# add wave -noupdate -radix hexadecimal /vhdlib_tb/dut/prbs_out
add wave -noupdate /vhdlib_tb/dut/*

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

