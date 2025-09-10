import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

from testbench_lib.axi import AXI4SBus, AXI4SDriver, AXI4SMonitor
from testbench_lib.core import BaseScoreboard, Bytes, Module

random.seed(0)

def random_bytes(n: int) -> Bytes:
    return Bytes(random.getrandbits(8) for _ in range(n))

async def watchdog(clock, timeout_cycles: int):
    await ClockCycles(clock, timeout_cycles)
    raise TimeoutError(f"Simulation timed out after {timeout_cycles} clock cycles")

async def reset_sequence(reset, clock, cycles: int = 10) -> None:
    reset.value = 1
    for _ in range(cycles):
        await RisingEdge(clock)
    reset.value = 0
    await RisingEdge(clock)

@cocotb.test()
async def test_skid_buffer(dut):
    module = Module(dut)

    # ------------------------------------------------------------------
    #  Configuration
    # ------------------------------------------------------------------

    NSAMPLES = 10000 # how many packets
    MAX_PACKET_SIZE  = 64 # max payload length
    SLAVE_STALL_PROBABILITY = 0.1 # Chance of AXI slave not ready.
    MASTER_STALL_PROBABILITY = 0.1 # Chance of Master not ready (valid low).

    # ------------------------------------------------------------------
    #  Hook up interfaces
    # ------------------------------------------------------------------

    s_axis = AXI4SBus(
        module  = module,
        signals = {
            "tdata"  : "s_tdata_o",
            "tvalid" : "s_tvalid_o",
            "tready" : "s_tready_i",
            "tlast"  : "s_tlast_o",
            "tkeep"  : "s_tkeep_o",
        }
    )

    m_axis = AXI4SBus(
        module  = module,
        signals = {
            "tdata"  : "m_tdata_i",
            "tvalid" : "m_tvalid_i",
            "tready" : "m_tready_o",
            "tlast"  : "m_tlast_i",
            "tkeep"  : "m_tkeep_i",
        }
    )

    scoreboard = BaseScoreboard(
        process_transaction_callback=lambda x: x,
        expected_matches=NSAMPLES,
    )

    driver = AXI4SDriver(
        clock             = module.clk_i,
        port              = m_axis,
        pre_delay_range   = range(0, 10),
        post_delay_range  = range(0, 10),
        stall_probability = MASTER_STALL_PROBABILITY,
        expect_callback   = scoreboard.expect_transaction,
    )

    monitor = AXI4SMonitor(
        clock             = module.clk_i,
        port              = s_axis,
        receive_callback  = scoreboard.receive_transaction,
        stall_probability = SLAVE_STALL_PROBABILITY,
    )

    # ------------------------------------------------------------------
    #  Stimulus – send N random packets
    # ------------------------------------------------------------------
    cocotb.start_soon(Clock(module.clk_i, 10, 'ns').start(start_high=False))
    monitor.start()

    await reset_sequence(module.rst_i, module.clk_i)

    transactions = [random_bytes(random.randint(1, MAX_PACKET_SIZE)) for _ in range(NSAMPLES)]
    driver.load_transaction_queue(transactions)
    driver.start()

    await watchdog(module.clk_i, 1000000)
