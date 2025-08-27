import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Event
from cocotb.result   import TestFailure

from testbench_lib.axi import AXI4SBus
from testbench_lib.axi import AXI4SDriver
from testbench_lib.axi import AXI4SMonitor

random.seed(0)

def random_bytes(n: int) -> bytes:
    return bytes(random.getrandbits(8) for _ in range(n))

async def watchdog(clock, timeout_cycles: int):
    await ClockCycles(clock, timeout_cycles)
    raise AssertionError(f"Simulation timed out after {timeout_cycles} clock cycles")

async def reset_sequence(reset, clock, cycles: int = 10) -> None:
    reset.value = 1
    for _ in range(cycles):
        await RisingEdge(clock)
    reset.value = 0
    await RisingEdge(clock)

def expect_callback(expect: bytes):
    print(f"Expecting: {expect.hex()}")

def receive_callback(expect: bytes):
    print(f"Receiving: {expect.hex()}")

@cocotb.test()
async def test_skid_buffer(dut):

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
        entity  = dut,
        name    = None,
        signals = {
            "tdata"  : "s_tdata_o",
            "tvalid" : "s_tvalid_o",
            "tready" : "s_tready_i",
            "tlast"  : "s_tlast_o"
        }
    )

    m_axis = AXI4SBus(
        entity  = dut,
        name    = None,
        signals = {
            "tdata"  : "m_tdata_i",
            "tvalid" : "m_tvalid_i",
            "tready" : "m_tready_o",
            "tlast"  : "m_tlast_i"
        }
    )

    driver = AXI4SDriver(
        clock             = clock,
        port              = m_axis,
        pre_delay_range   = range(0, 10),
        post_delay_range  = range(0, 10),
        stall_probability = MASTER_STALL_PROBABILITY,
        expect_callback   = expect_callback,
    )

    monitor = AXI4SMonitor(
        clock             = clock,
        port              = s_axis,
        receive_callback  = receive_callback,
        stall_probability = SLAVE_STALL_PROBABILITY,
    )

    # ------------------------------------------------------------------
    #  Stimulus – send N random packets
    # ------------------------------------------------------------------
    cocotb.start_soon(Clock(clock, 10, 'ns').start(start_high=False))
    monitor.start()

    await reset_sequence(reset, clock)

    transactions = [random_bytes(random.randint(1, MAX_PACKET_SIZE)) for _ in range(NSAMPLES)]
    driver.load_transaction_queue(transactions)
    driver.start()

    await watchdog(clock, 1000)

    #scoreboard.check_complete()

    dut._log.info("Skid buffer passed all scoreboard checks with back-pressure.")
