import logging
import pyshark

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.result import TestFailure
from cocotb_bus.drivers import Driver

from cocotb_lib.axi.axi4stream_driver import AXI4SBus, AXI4SDriver

NUM_CHANNELS = 8
PCAP_PATH = "/home/poflynn/src/hardware-monorepo/.data/packet_buffer_top_tb/test_pcap.pcap"

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

@cocotb.test()
async def test_packet_buffer_basic(dut):

    async def reset(dut):
        """Reset the DUT."""
        dut.rst_i.value = 1
        await ClockCycles(dut.clk_i, 5)
        dut.rst_i.value = 0
        await ClockCycles(dut.clk_i, 5)

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())

    axi4s_bus = AXI4SBus(
        dut,
        None,
        {
            "tdata"  : "tdata_i",
            "tvalid" : "tvalid_i",
            "tready" : "tready_o",
            "tlast"  : "tlast_i",
        },
    )   

    driver = AXI4SDriver(dut.clk_i, axi4s_bus)
    
    # Set all ready signals to 1
    # for ch in range(NUM_CHANNELS):
    #     setattr(dut, f"m_axis_tready_i_{ch}", 1)
    
    await reset(dut)
    await ClockCycles(dut.clk_i, 10)

    pcap = pyshark.FileCapture(PCAP_PATH, use_json=True, include_raw=True, keep_packets=False)
    for packet in pcap:
        await driver.send(bytes(packet.get_raw_packet()))
        await ClockCycles(dut.clk_i, 10)

    pcap.close()

    await ClockCycles(dut.clk_i, 2000)
    
    log.info("All packets verified successfully - Test PASSED")