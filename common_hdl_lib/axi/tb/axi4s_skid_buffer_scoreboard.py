from typing import Deque

import cocotb
from cocotb_bus.scoreboard import Scoreboard

from cocotb_lib.axi.axi4stream_monitor import AXI4SMonitor

class AXI4SSkidBufferScoreboard(Scoreboard):
    def __init__(self, dut, monitor: AXI4SMonitor, expected_queue: list[bytes]):
        super().__init__(dut)
        self.add_interface(monitor, expected_queue)
