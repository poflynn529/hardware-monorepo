from typing import override

from cocotb.triggers import RisingEdge
from cocotb_bus.bus import Bus
from cocotb_bus.drivers import Driver

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

class AXI4SDriver(Driver):
    """Generic AXI4-Stream driver based on *cocotb-bus* Driver.

    Parameters
    ----------
    entity : SimHandleBase
        The parent DUT object (usually *dut*).
    clock : SimHandleBase
        Handle to the clock driving the AXI domain.
    bus : AXI4SBus
        Instance of :class:`AXI4SBus` connected to the DUT port to drive.
    """

    def __init__(self, clock, bus: AXI4SBus):
        super().__init__()
        self.clock = clock
        self.bus = bus
        self.data_width = len(self.bus.tdata)

        assert self.data_width % 8 == 0, "TDATA width must be an integer multiple of 8 bits"
        self.byte_width = self.data_width // 8

        # Initialise interface
        self.bus.tvalid.setimmediatevalue(0)
        self.bus.tdata.setimmediatevalue(0)
        self.bus.tlast.setimmediatevalue(0)
        #self.bus.tkeep.setimmediatevalue(0)

    @override
    async def _driver_send(self, data: bytes, sync: bool = True):
        offset = 0
        while offset < len(data):
            chunk = data[offset : offset + self.byte_width]
            word = int.from_bytes(chunk.ljust(self.byte_width, b"\0"), "little")

            # Present data and assert TVALID
            self.bus.tdata.value = word
            self.bus.tvalid.value = 1
            self.bus.tlast.value = int(offset + self.byte_width >= len(data))
            #self.bus.tkeep.value = (1 << len(chunk)) - 1

            # Wait for handshake
            while True:
                await RisingEdge(self.clock)
                if self.bus.tready.value:
                    break
            
            offset += self.byte_width
            self.bus.tvalid.value = 0
            self.bus.tlast.value = 0
            #self.bus.tkeep.value = 0
            