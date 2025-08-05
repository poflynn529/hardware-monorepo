from collections import deque
from random import random
from typing import Deque, override

import cocotb.log as log
from cocotb_bus.monitors import Monitor
from cocotb.triggers import RisingEdge, ReadOnly

from axi4stream_bus import AXI4SBus

class AXI4SMonitor(Monitor):
    """Observe an AXI4-Stream interface and emit byte packets."""

    def __init__(
        self,
        clock,
        bus: AXI4SBus,
        callback=None,
        event=None,
        stall_probability=0
    ) -> None:
        self.clock = clock
        self.bus = bus
        self.stall_probability = stall_probability
        self.byte_width = len(self.bus.tdata) // 8
        self._current_words: Deque[int] = deque()
        self.name = None
        super().__init__(callback, event)

    async def _monitor_recv(self):
        while True:
            await RisingEdge(self.clock)
            self.bus.tready.value = int(random() > self.stall_probability)
            await ReadOnly()

            if int(self.bus.tvalid) and int(self.bus.tready):
                self._current_words.append(int(self.bus.tdata))

                if int(self.bus.tlast):
                    pkt = bytearray()
                    for w in self._current_words:
                        pkt.extend(w.to_bytes(self.byte_width, "little"))
                    self._current_words.clear()
                    self._recv(bytes(pkt))
