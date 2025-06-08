# ---- packet_buffer_tb Makefile ----

TOPLEVEL := packet_buffer
MODULE   := packet_buffer_tb_top
SIM      := verilator

EXTRA_ARGS += --trace --trace-fst --trace-structs

PYTHONPATH := cocotb_lib/axi/:fpgashark/packet_buffer/tb/
export PYTHONPATH

VERILOG_SOURCES = \
	verilator_xpm/FIFO36E2.v \
	common_hdl_lib/utils/src/utils.sv \
	common_hdl_lib/mux/src/vector_muxcy.sv \
	common_hdl_lib/fifo/src/fifo36e2_wrapper.sv \
	common_hdl_lib/axi/src/axi4s_skid_buffer.sv \
	fpgashark/packet_buffer/pkg/packet_buffer_pkg.sv \
	fpgashark/packet_buffer/src/packet_buffer_write_controller.sv \
	fpgashark/packet_buffer/src/packet_buffer.sv

include $(shell cocotb-config --makefiles)/Makefile.sim
