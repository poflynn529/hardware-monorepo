import random
from typing import override

from cocotb.triggers import RisingEdge, ReadOnly
from cocotb_bus.drivers import Driver

from axi4stream_bus import AXI4SBus

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

    def __init__(self, clock, bus: AXI4SBus, pre_delay_range=None, post_delay_range=None, stall_probability=0.0):
        super().__init__()
        self.clock = clock
        self.bus = bus
        self.data_width = len(self.bus.tdata)
        self.pre_delay_range = pre_delay_range
        self.post_delay_range = post_delay_range
        self.stall_probability = stall_probability

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

        if self.pre_delay_range:
            delay = random.randint(self.pre_delay_range[0], self.pre_delay_range[1])
            for _ in range(delay):
                await RisingEdge(self.clock)

        while offset < len(data):
            chunk = data[offset : offset + self.byte_width]
            word = int.from_bytes(chunk.ljust(self.byte_width, b"\0"), "little")

            self.bus.tdata.value = word
            self.bus.tlast.value = int(offset + self.byte_width >= len(data))
            #self.bus.tkeep.value = (1 << len(chunk)) - 1

            # tvalid may go low during the transfer, but once it goes high,
            # it must remain high until the transfer is accepted.
            while True:
                self.bus.tvalid.value = int(random.random() > self.stall_probability)
                await ReadOnly()
                if self.bus.tvalid.value:
                    break
                await RisingEdge(self.clock)

            # Wait for handshake.
            while True:
                if int(self.bus.tready.value):
                    break
                await RisingEdge(self.clock)
                await ReadOnly()

            offset += self.byte_width
            await RisingEdge(self.clock)

        self.bus.tvalid.value = 0
        self.bus.tlast.value = 0
        #self.bus.tkeep.value = 0

        if self.post_delay_range:
            delay = random.randint(self.post_delay_range[0], self.post_delay_range[1])
            for _ in range(delay):
                await RisingEdge(self.clock)

# Issue with holding the data unneccesarily for an extra cycle after an input stall.