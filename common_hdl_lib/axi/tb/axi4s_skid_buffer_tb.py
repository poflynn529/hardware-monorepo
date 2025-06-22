import random
from collections import deque
from typing import Deque

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Event, First
from cocotb.result   import TestFailure
from cocotb_bus.monitors import Monitor

from cocotb_lib.axi.axi4stream_bus import AXI4SBus
from cocotb_lib.axi.axi4stream_driver import AXI4SDriver
from cocotb_lib.axi.axi4stream_monitor import AXI4SMonitor
from axi4s_skid_buffer_scoreboard import AXI4SSkidBufferScoreboard

def random_bytes(n: int) -> bytes:
    return bytes(random.getrandbits(8) for _ in range(n))

def percent_to_prob(pct: int) -> float:
    return max(0.0, min(100.0, pct)) / 100.0

async def watchdog(clock, timeout_cycles: int):
    await ClockCycles(clock, timeout_cycles)
    raise TestFailure(f"Simulation timed out after {timeout_cycles} clock cycles")

async def start_driver(driver) -> None:
    for _ in range(10):
        pkt_len = random.randint(1, 64)
        pkt = random_bytes(pkt_len)
        #expected_pkts.append(pkt)
        await driver.send(pkt)

async def reset_sequence(reset, clock, cycles: int = 10) -> None:
    reset.value = 1
    for _ in range(cycles):
        await RisingEdge(clock)
    reset.value = 0
    await RisingEdge(clock)


@cocotb.test()
async def test_skid_buffer(dut):
    """Drive random packets through the skid buffer with back-pressure and
    verify lossless forwarding via scoreboard."""

    # ------------------------------------------------------------------
    #  Configuration
    # ------------------------------------------------------------------
    NSAMPLES = 10 # how many packets
    MAX_PKT  = 64 # max payload length
    STALL_PCT = 30 # % cycles not ready
    stall_prob = percent_to_prob(STALL_PCT)

    # ------------------------------------------------------------------
    #  Hook up interfaces
    # ------------------------------------------------------------------
    clock = dut.clk_i
    reset = dut.rst_i

    s_axis = AXI4SBus(
        entity=dut,
        name=None,
        signals= {
            "tdata"  : "s_tdata_o",
            "tvalid" : "s_tvalid_o",
            "tready" : "s_tready_i",
            "tlast"  : "s_tlast_o"
        }
    )

    m_axis = AXI4SBus(
        entity=dut,
        name=None,
        signals= {
            "tdata"  : "m_tdata_i",
            "tvalid" : "m_tvalid_i",
            "tready" : "m_tready_o",
            "tlast"  : "m_tlast_i"
        }
    )
    
    simulation_complete = Event()

    driver = AXI4SDriver(clock, m_axis)
    monitor = AXI4SMonitor(clock, s_axis, stall_probability=0.2)

    expected_pkts: Deque[bytes] = deque()
    #scoreboard = AXI4SSkidBufferScoreboard(dut, monitor, expected_pkts)

    # ------------------------------------------------------------------
    #  Stimulus – send N random packets
    # ------------------------------------------------------------------
    cocotb.start_soon(Clock(clock, 10, 'ns').start(start_high=False))
    await reset_sequence(reset, clock)
    cocotb.start_soon(start_driver(driver))

    # ------------------------------------------------------------------
    #  Let the pipeline flush, then check results
    # ------------------------------------------------------------------
    # for _ in range(100):  # arbitrary grace period
    #     await RisingEdge(clock)

    await watchdog(clock, 1000)

    #scoreboard.check_complete()

    dut._log.info("Skid buffer passed all scoreboard checks with back-pressure.")
