import random

import cocotb

from cocotb_lib.axi.axi4stream_bus import AXI4SBus
from cocotb_lib.axi.axi4stream_driver import AXI4SDriver
from cocotb_lib.axi.axi4stream_monitor import AXI4SMonitor

def random_bytes(n: int) -> bytes:
    return bytes(random.getrandbits(8) for _ in range(n))


def percent_to_prob(pct: int) -> float:
    return max(0.0, min(100.0, pct)) / 100.0

# -----------------------------------------------------------------------------
#  The main cocotb test
# -----------------------------------------------------------------------------

@cocotb.test()
async def test_skid_buffer(dut):
    """Drive random packets through the skid buffer with back‑pressure and
    verify loss‑less forwarding via scoreboard."""

    # ------------------------------------------------------------------
    #  Configuration
    # ------------------------------------------------------------------
    NSAMPLES = int(os.getenv("NSAMPLES", "10"))      # how many packets
    MAX_PKT   = int(os.getenv("MAX_PKT", "64"))      # max payload length
    STALL_PCT = int(os.getenv("STALL_PCT", "30"))    # % cycles not ready
    stall_prob = percent_to_prob(STALL_PCT)
    random.seed(0xC0C0_2025)  # deterministic but changeable

    # ------------------------------------------------------------------
    #  Hook up interfaces
    # ------------------------------------------------------------------
    clock = dut.clk
    s_axis = AXI4SBus.from_prefix(dut, "s_axis")
    m_axis = AXI4SBus.from_prefix(dut, "m_axis")

    driver = AXI4SDriver(clock, s_axis)
    monitor = AXI4SMonitor(clock, m_axis)
    monitor.start()

    expected_pkts: Deque[bytes] = deque()
    scoreboard = AXI4SScoreboard(dut, monitor, expected_pkts)

    # ------------------------------------------------------------------
    #  Generate back‑pressure on m_axis.tready
    # ------------------------------------------------------------------
    m_axis.tready.setimmediatevalue(0)

    async def toggle_ready():
        while True:
            await RisingEdge(clock)
            m_axis.tready.value = int(random.random() > stall_prob)

    cocotb.start_soon(toggle_ready())

    # ------------------------------------------------------------------
    #  Stimulus – send N random packets
    # ------------------------------------------------------------------
    for _ in range(NSAMPLES):
        pkt_len = random.randint(1, MAX_PKT)
        pkt = random_bytes(pkt_len)
        expected_pkts.append(pkt)
        await driver.send(pkt)

    # ------------------------------------------------------------------
    #  Let the pipeline flush, then check results
    # ------------------------------------------------------------------
    for _ in range(50):  # arbitrary grace period
        await RisingEdge(clock)

    scoreboard.check_complete()

    dut._log.info("Skid buffer passed all scoreboard checks with back‑pressure.")