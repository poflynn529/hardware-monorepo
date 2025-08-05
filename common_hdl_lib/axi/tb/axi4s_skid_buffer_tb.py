import random
from collections import deque
from typing import Deque

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Event
from cocotb.result   import TestFailure

from cocotb_lib.axi.axi4stream_bus import AXI4SBus
from cocotb_lib.axi.axi4stream_driver import AXI4SDriver
from cocotb_lib.axi.axi4stream_monitor import AXI4SMonitor
from axi4s_skid_buffer_scoreboard import AXI4SSkidBufferScoreboard

random.seed(0)

def random_bytes(n: int) -> bytes:
    return bytes(random.getrandbits(8) for _ in range(n))

async def watchdog(clock, timeout_cycles: int):
    await ClockCycles(clock, timeout_cycles)
    raise TestFailure(f"Simulation timed out after {timeout_cycles} clock cycles")

async def start_driver(driver, max_packet_size, nsamples) -> None:
    for _ in range(nsamples):
        pkt_len = random.randint(1, max_packet_size)
        pkt = random_bytes(pkt_len)
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
    NSAMPLES = 25 # how many packets
    MAX_PACKET_SIZE  = 64 # max payload length
    SLAVE_STALL_PROBABILITY = 0.1 # Chance of AXI slave not ready.
    MASTER_STALL_PROBABILITY = 0.0 # Chance of Master not ready (valid low).

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

    expected_pkts: list[bytes] = list()

    monitor = AXI4SMonitor(
        clock,
        s_axis,
        stall_probability=SLAVE_STALL_PROBABILITY
    )

    driver = AXI4SDriver(
        clock,
        m_axis,
        pre_delay_range=(0, 10),
        post_delay_range=(0, 10),
        stall_probability=MASTER_STALL_PROBABILITY,
        expect_queue=expected_pkts
    )

    scoreboard = AXI4SSkidBufferScoreboard(dut, monitor, expected_pkts)

    # ------------------------------------------------------------------
    #  Stimulus – send N random packets
    # ------------------------------------------------------------------
    cocotb.start_soon(Clock(clock, 10, 'ns').start(start_high=False))
    await reset_sequence(reset, clock)
    cocotb.start_soon(start_driver(driver, MAX_PACKET_SIZE, NSAMPLES))

    # ------------------------------------------------------------------
    #  Let the pipeline flush, then check results
    # ------------------------------------------------------------------
    # for _ in range(100):  # arbitrary grace period
    #     await RisingEdge(clock)

    await watchdog(clock, 1000)

    #scoreboard.check_complete()

    dut._log.info("Skid buffer passed all scoreboard checks with back-pressure.")
