from random import random
from dataclasses import dataclass
from typing import override

from cocotb.triggers import RisingEdge, ReadOnly
from testbench_lib.core import BaseMonitor

@dataclass
class AXI4SMonitor(BaseMonitor):

    stall_probability: float

    @override
    async def _receive(self) -> bytes:
        while True:
            await RisingEdge(self.clock)
            self.port.tready.value = int(random() > self.stall_probability)
            await ReadOnly()

            if int(self.port.tvalid): # Start of packet
                received_words = bytearray()
                while True:

                    if int(self.port.tvalid) and int(self.port.tready):
                        word = int(self.port.tdata)
                        received_words.extend(word.to_bytes(self.port.tdata.value.n_bits // 8, "little"))

                    if int(self.port.tlast) and int(self.port.tready): break # End of packet

                    await RisingEdge(self.clock)
                    self.port.tready.value = int(random() > self.stall_probability)
                    await ReadOnly()

                self.receive_callback(bytes(received_words))

            else:
                continue
