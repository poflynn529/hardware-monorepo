from typing import Deque

import cocotb
from cocotb_bus.scoreboard import Scoreboard

from cocotb_lib.axi.axi4stream_monitor import AXI4SMonitor

class AXI4SSkidBufferScoreboard(Scoreboard):
    def __init__(self, dut, monitor: AXI4SMonitor, exp_queue: Deque[bytes]):
        super().__init__(dut)
        self.add_interface(monitor, lambda: exp_queue.popleft())
        self.exp_queue = exp_queue

    def check_complete(self):
        if self.exp_queue:
            raise cocotb.result.TestFailure(
                f"{len(self.exp_queue)} expected packet(s) were never seen"
            )
        self.result()