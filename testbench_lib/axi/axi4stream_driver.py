import random
from dataclasses import dataclass
from typing import override
from cocotb.triggers import RisingEdge, ReadOnly
from testbench_lib.core import BaseDriver

@dataclass
class AXI4SDriver(BaseDriver):
    stall_probability: float = 0.0

    def __post_init__(self):
        self.axi_width = self.port.tdata.value.n_bits
        assert self.axi_width % 8 == 0, "TDATA width must be an integer multiple of 8 bits"
        self.byte_width = self.axi_width // 8

        self.port.tvalid.setimmediatevalue(0)
        self.port.tdata.setimmediatevalue(0)
        self.port.tlast.setimmediatevalue(0)
        #self.port.tkeep.setimmediatevalue(0)

    @override
    async def _drive_transaction(self, data: bytes):
        offset = 0

        while offset < len(data):
            chunk = data[offset : offset + self.byte_width]
            word = int.from_bytes(chunk.ljust(self.byte_width, b"\0"), "little")

            self.port.tdata.value = word
            self.port.tlast.value = int(offset + self.byte_width >= len(data))
            #self.port.tkeep.value = (1 << len(chunk)) - 1

            while True:
                self.port.tvalid.value = int(random.random() > self.stall_probability)
                await ReadOnly()
                if self.port.tvalid.value:
                    break
                await RisingEdge(self.clock)

            # Wait for handshake.
            while True:
                if int(self.port.tready.value):
                    break
                await RisingEdge(self.clock)
                await ReadOnly()

            offset += self.byte_width
            await RisingEdge(self.clock)

        self.port.tvalid.value = 0
        self.port.tlast.value = 0
        #self.port.tkeep.value = 0

# Issue with holding the data unneccesarily for an extra cycle after an input stall.
