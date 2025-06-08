from collections import deque
from typing import Deque, override

from cocotb_bus.monitors import Monitor
from cocotb.triggers import RisingEdge, ReadOnly

from axi4stream_bus import AXI4SBus

class AXI4SMonitor(Monitor):
    """Observe an AXI4‑Stream interface and emit byte packets."""

    def __init__(
        self,
        clock,
        bus: AXI4SBus,
        callback=None,
        event=None,
    ) -> None:
        super().__init__(callback, event)
        self.clock = clock
        self.bus = bus
        self.byte_width = len(self.bus.tdata) // 8
        self._cur_words: Deque[int] = deque()

    @override  # type: ignore[override]
    async def _monitor_recv(self):
        while True:
            await RisingEdge(self.clock)
            await ReadOnly()
            if int(self.bus.tvalid) and int(self.bus.tready):
                self._cur_words.append(int(self.bus.tdata))
                if int(self.bus.tlast):
                    pkt = bytearray()
                    for w in self._cur_words:
                        pkt.extend(w.to_bytes(self.byte_width, "little"))
                    pkt = pkt.rstrip(b"\0")
                    self._cur_words.clear()
                    self._recv(bytes(pkt))