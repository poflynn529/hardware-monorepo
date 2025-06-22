from cocotb_bus.bus import Bus

class AXI4SBus(Bus):
    """Convenience wrapper exposing the canonical AXI4-Stream handshake.

    TODO: Extend *_signals* to expose additional side-band ports
    such as TSTRB, TID, or TDEST.
    """

    _signals = [
        "tdata",
        "tvalid",
        "tready",
        "tlast",
        "tkeep",
    ]
