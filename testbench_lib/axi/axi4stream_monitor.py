from random import random
from typing import override

from cocotb.triggers import RisingEdge, ReadOnly
from testbench_lib.core import BaseMonitor, Bytes


class AXI4SMonitor(BaseMonitor):

    @override
    async def _receive(self) -> Bytes:
        while True:
            await RisingEdge(self.clock)
            self.port.tready.value = int(random() > self._config["monitor_stall_probability"])
            await ReadOnly()

            if self.port.tvalid.value: # Start of packet
                received_words = bytearray()
                while True:

                    if self.port.tvalid.value and self.port.tready.value:
                        mask: int = self.port.tkeep.value.to_unsigned()
                        word_bytes = Bytes(self.port.tdata.value.to_bytes(byteorder="little"))

                        for i in range(len(word_bytes)):
                            if (mask >> i) & 1:
                                received_words.append(word_bytes[i])

                    if self.port.tlast.value and self.port.tready.value: break # End of packet

                    await RisingEdge(self.clock)
                    self.port.tready.value = random() > self._config["monitor_stall_probability"]
                    await ReadOnly()

                self.receive_callback(Bytes(received_words))

            else:
                continue
