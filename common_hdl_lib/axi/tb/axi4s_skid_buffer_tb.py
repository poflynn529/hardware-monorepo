import random
from typing import Any

import cocotb
from testbench_lib.axi import AXI4SBus, AXI4SDriver, AXI4SMonitor
from testbench_lib.core import BaseScoreboard, BaseEnvironment, ResetSequence, Module, BASE_CONFIG

from testbench_lib.core import BaseScoreboard, Bytes, Module

def random_byte_stream(config: dict[str, Any]) -> list[Bytes]:
    transactions = []
    for _ in range(config["num_transactions"]):
        random_bytes = []
        for _ in range(random.randint(1, config["max_packet_size"])):
            random_bytes.append(random.getrandbits(8))
        transactions.append(Bytes(random_bytes))
    return transactions

def build_config() -> dict[str, Any]:
    base = BASE_CONFIG.copy()
    base["scoreboard_expected_matches"] = 1000

    config = {
        "monitor_stall_probability" : None, # Chance of AXI slave not ready.
        "driver_stall_probability"  : None, # Chance of Master not ready (valid low).
        "num_transactions"          : 1000,
        "max_packet_size"           : 64,
    }

    return base | config


def build_env(module: Module) -> BaseEnvironment:

    slave_axis = AXI4SBus(
        module  = module,
        signals = {
            "tdata"  : "s_tdata_o",
            "tvalid" : "s_tvalid_o",
            "tready" : "s_tready_i",
            "tlast"  : "s_tlast_o",
            "tkeep"  : "s_tkeep_o",
        }
    )

    master_axis = AXI4SBus(
        module  = module,
        signals = {
            "tdata"  : "m_tdata_i",
            "tvalid" : "m_tvalid_i",
            "tready" : "m_tready_o",
            "tlast"  : "m_tlast_i",
            "tkeep"  : "m_tkeep_i",
        }
    )
    env = BaseEnvironment()
    env.set_clock(module.clk_i)
    env.add_reset(
        ResetSequence(
            clock      = module.clk_i,
            reset      = module.rst_i,
            num_cycles = 10
        )
    )
    env.set_scoreboard(
        BaseScoreboard(
            process_transaction_callback=lambda x: x,
        )
    )
    env.add_driver(
        "AXI4S Master Driver",
        AXI4SDriver(
            clock             = module.clk_i,
            port              = master_axis,
            expect_callback   = env._scoreboard.expect_transaction,
        ),
        transaction_generator = random_byte_stream
    )
    env.add_monitor(
        "AXI4S Slave Monitor",
        AXI4SMonitor(
            clock             = module.clk_i,
            port              = slave_axis,
            receive_callback  = env._scoreboard.receive_transaction,
        )
    )

    return env

@cocotb.test()
@cocotb.parametrize(
    master_stall_probability=[0, 0.1, 0.95],
    slave_stall_probability=[0, 0.1, 0.95]
)
async def test(dut, master_stall_probability, slave_stall_probability):
    env = build_env(Module(dut))
    config = build_config()
    config["driver_stall_probability"] = master_stall_probability
    config["monitor_stall_probability"] = slave_stall_probability
    env.set_configuration(config)
    await env.run()
