from random import random
from dataclasses import dataclass
from typing import override

from cocotb.triggers import RisingEdge, ReadOnly
from testbench_lib.core import BaseMonitor, Bytes

@dataclass
class AXI4SMonitor(BaseMonitor):

    stall_probability: float

    @override
    async def _receive(self) -> Bytes:
        while True:
            await RisingEdge(self.clock)
            self.port.tready.value = int(random() > self.stall_probability)
            await ReadOnly()

            if int(self.port.tvalid): # Start of packet
                received_words = bytearray()
                while True:

                    if int(self.port.tvalid) and int(self.port.tready):
                        word = int(self.port.tdata)
                        mask = int(self.port.tkeep)
                        word_bytes = word.to_bytes(self.port.tdata.value.n_bits // 8, "little")

                        for i in range(len(word_bytes)):
                            if (mask >> i) & 1:
                                received_words.append(word_bytes[i])

                    if int(self.port.tlast) and int(self.port.tready): break # End of packet

                    await RisingEdge(self.clock)
                    self.port.tready.value = int(random() > self.stall_probability)
                    await ReadOnly()

                self.receive_callback(Bytes(received_words))

            else:
                continue
