# ---- packet_buffer_tb Makefile ----

TOPLEVEL := packet_buffer
MODULE   := packet_buffer_tb_top
SIM      := verilator

EXTRA_ARGS += --trace --trace-fst --trace-structs

export PYTHONPATH := fpgashark/packet_buffer/tb

VERILOG_SOURCES = \
	common_lib/utils/utils.sv \
	verilator_xpm/FIFO36E2.v \
	fpgashark/packet_buffer/src/vector_muxcy.sv \
	fpgashark/packet_buffer/src/fifo36e2_wrapper.sv \
	fpgashark/packet_buffer/src/axi4s_skid_buffer.sv \
	fpgashark/packet_buffer/pkg/packet_buffer_pkg.sv \
	fpgashark/packet_buffer/src/packet_buffer_write_controller.sv \
	fpgashark/packet_buffer/src/packet_buffer.sv

include $(shell cocotb-config --makefiles)/Makefile.sim
