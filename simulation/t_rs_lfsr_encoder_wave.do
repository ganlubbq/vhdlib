onerror {resume}

quietly WaveActivateNextPane {} 0
add wave -noupdate /vhdlib_tb/dut/clk
add wave -noupdate /vhdlib_tb/dut/rst
add wave -noupdate /vhdlib_tb/dut/som
add wave -noupdate -radix unsigned /vhdlib_tb/dut/msg
add wave -noupdate /vhdlib_tb/dut/soc
add wave -noupdate /vhdlib_tb/dut/eoc
add wave -noupdate -radix unsigned /vhdlib_tb/dut/cw
add wave -noupdate -radix unsigned /vhdlib_tb/dut/mul_out
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gf_regs
add wave -noupdate -radix unsigned /vhdlib_tb/dut/gf_regs_fb
add wave -noupdate -radix unsigned /vhdlib_tb/dut/msg_xor
add wave -noupdate -radix unsigned /vhdlib_tb/dut/codeword_cnt

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

