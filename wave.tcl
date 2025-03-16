open_vcd waveform.vcd
log_vcd [get_objects /xilinx_bram_tb/dut/* /xilinx_bram_tb/*]
run all
close_vcd
quit
