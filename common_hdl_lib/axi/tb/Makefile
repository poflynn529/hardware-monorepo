# ---- axi4s_skid_buffer_tb Makefile ----

TOPLEVEL := axi4s_skid_buffer
MODULE   := axi4s_skid_buffer_tb
SIM      := verilator

EXTRA_ARGS += --trace --trace-fst --trace-structs
# TODO: Actually figure out how to do this.
# VERILATOR_COMPILE_ARGS += -GAXI_WIDTH=64

PYTHONPATH := testbench_lib/axi/:testbench_lib/core/:common_hdl_lib/axi/tb/:
export PYTHONPATH

VERILOG_SOURCES = \
  common_hdl_lib/axi/src/axi4s_skid_buffer.sv

include $(shell cocotb-config --makefiles)/Makefile.sim
