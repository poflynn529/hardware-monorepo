import random
from typing import override
from dataclasses import dataclass
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb.handle import Immediate
from testbench_lib.core import BaseDriver, Bytes

@dataclass
class AXI4SDriver(BaseDriver):

    def __post_init__(self):
        self.axi_width = len(self.port.tdata)
        assert self.axi_width % 8 == 0, "TDATA width must be an integer multiple of 8 bits"
        self.byte_width = self.axi_width // 8

        self.port.tvalid.set(Immediate(0))
        self.port.tdata.set(Immediate(0))
        self.port.tlast.set(Immediate(0))
        self.port.tkeep.set(Immediate(0))

    @override
    async def _drive_transaction(self, data: Bytes):
        offset = 0

        while offset < len(data):
            chunk = data[offset : offset + self.byte_width]
            word = int.from_bytes(chunk.ljust(self.byte_width, b"\0"), "little")

            self.port.tdata.value = word
            self.port.tlast.value = int(offset + self.byte_width >= len(data))
            self.port.tkeep.value = (1 << len(chunk)) - 1

            while True:
                self.port.tvalid.value = int(random.random() > self._config["driver_stall_probability"])
                await ReadOnly()
                if self.port.tvalid.value:
                    break
                await RisingEdge(self.clock)

            # Wait for handshake.
            while True:
                if self.port.tready.value:
                    break
                await RisingEdge(self.clock)
                await ReadOnly()

            offset += self.byte_width
            await RisingEdge(self.clock)

        self.port.tvalid.value = 0
        self.port.tlast.value = 0
        self.port.tkeep.value = 0
