open_vcd waveform.vcd
log_vcd [get_objects /packet_buffer_tb_top/dut/* /packet_buffer_tb_top/*]
run all
close_vcd
quit
