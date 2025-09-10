from testbench_lib.core import Bus

class AXI4SBus(Bus):
    signals = (
        "tdata",
        "tvalid",
        "tready",
        "tlast",
        "tkeep",
    )
