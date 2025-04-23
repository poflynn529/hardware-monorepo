#!/usr/bin/env python3
"""
Packet Buffer CocoTB Testbench
"""

import pytest
import random
import logging
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
from cocotb.result import TestFailure
from cocotb.binary import BinaryValue

# Configure logging
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Constants for packet buffer
OUTPUT_WIDTH = 8  # Width of output in bits
NUM_CHANNELS = 8  # Number of channels

class PacketHeader:
    """Class representing a packet header."""
    def __init__(self, packet_length=0, interface_id=0):
        self.packet_length = packet_length
        self.interface_id = interface_id
    
    def to_bytes(self):
        """Convert header to bytes for transmission."""
        # Two bytes for packet length, two bytes for interface ID
        return (self.packet_length.to_bytes(2, byteorder='big') +
                self.interface_id.to_bytes(2, byteorder='big'))

class PacketGenerator:
    """Generates test packets for simulation."""
    def __init__(self, min_size=64, max_size=1500):
        self.min_size = min_size
        self.max_size = max_size
    
    def generate_packet(self, interface_id=0, fixed_size=None):
        """Generate a random packet with header."""
        # Generate random packet length if not specified
        pkt_len = fixed_size if fixed_size is not None else random.randint(self.min_size, self.max_size)
        
        # Create header
        header = PacketHeader(packet_length=pkt_len, interface_id=interface_id)
        
        # Generate random payload
        payload = bytes([random.randint(0, 255) for _ in range(pkt_len)])
        
        return header, payload

class PacketBufferDriver:
    """Drives the packet buffer input interface."""
    def __init__(self, dut, clock):
        self.dut = dut
        self.clock = clock
        self.generator = PacketGenerator()
        
    async def reset(self):
        """Reset the DUT."""
        self.dut.rst_i.value = 1
        await ClockCycles(self.clock, 5)
        self.dut.rst_i.value = 0
        await ClockCycles(self.clock, 5)
    
    async def send_packet(self, interface_id=0, fixed_size=None):
        """Send a packet to the specified interface."""
        header, payload = self.generator.generate_packet(interface_id, fixed_size)
        log.info(f"Sending packet: length={header.packet_length}, interface_id={header.interface_id}")
        
        # Send header first
        header_bytes = header.to_bytes()
        for i, byte in enumerate(header_bytes):
            self.dut.s_axis_tdata_i.value = byte
            self.dut.s_axis_tvalid_i.value = 1
            self.dut.s_axis_tlast_i.value = 0
            
            # Wait for ready
            while True:
                await RisingEdge(self.clock)
                if self.dut.s_axis_tready_o.value == 1:
                    break
        
        # Send payload
        for i, byte in enumerate(payload):
            self.dut.s_axis_tdata_i.value = byte
            self.dut.s_axis_tvalid_i.value = 1
            self.dut.s_axis_tlast_i.value = 1 if i == len(payload) - 1 else 0
            
            # Wait for ready
            while True:
                await RisingEdge(self.clock)
                if self.dut.s_axis_tready_o.value == 1:
                    break
        
        # Clear valid signal
        self.dut.s_axis_tvalid_i.value = 0
        await RisingEdge(self.clock)
        
        return header, payload

class PacketBufferMonitor:
    """Monitors the packet buffer output interfaces."""
    def __init__(self, dut, clock):
        self.dut = dut
        self.clock = clock
        self.received_packets = [[] for _ in range(NUM_CHANNELS)]
        self.header_bytes = [[] for _ in range(NUM_CHANNELS)]
        self.payload_bytes = [[] for _ in range(NUM_CHANNELS)]
        self.state = ["IDLE" for _ in range(NUM_CHANNELS)]
        
    async def start_monitoring(self):
        """Start monitoring all output channels."""
        for ch in range(NUM_CHANNELS):
            cocotb.start_soon(self.monitor_channel(ch))
    
    async def monitor_channel(self, channel):
        """Monitor a specific output channel."""
        log.info(f"Starting monitor for channel {channel}")
        
        while True:
            await RisingEdge(self.clock)
            
            # Get channel-specific signals
            tvalid = getattr(self.dut, f"m_axis_tvalid_o_{channel}").value
            tready = getattr(self.dut, f"m_axis_tready_i_{channel}").value
            
            # Only sample when valid and ready are both high
            if tvalid == 1 and tready == 1:
                tdata = getattr(self.dut, f"m_axis_tdata_o_{channel}").value
                tlast = getattr(self.dut, f"m_axis_tlast_o_{channel}").value
                
                # Process based on current state
                if self.state[channel] == "IDLE":
                    # First byte, should be header
                    self.header_bytes[channel].append(int(tdata))
                    self.state[channel] = "COLLECT_HEADER"
                    
                elif self.state[channel] == "COLLECT_HEADER":
                    # Collect header bytes
                    self.header_bytes[channel].append(int(tdata))
                    
                    # If we have complete header (4 bytes)
                    if len(self.header_bytes[channel]) == 4:
                        # Extract packet length and interface ID
                        packet_length = (self.header_bytes[channel][0] << 8) | self.header_bytes[channel][1]
                        interface_id = (self.header_bytes[channel][2] << 8) | self.header_bytes[channel][3]
                        
                        log.debug(f"Channel {channel}: Header complete, packet length={packet_length}, interface_id={interface_id}")
                        self.state[channel] = "COLLECT_PAYLOAD"
                
                elif self.state[channel] == "COLLECT_PAYLOAD":
                    # Collect packet payload
                    self.payload_bytes[channel].append(int(tdata))
                    
                    # If this is the last byte of the packet
                    if tlast == 1 or len(self.payload_bytes[channel]) == packet_length:
                        log.info(f"Channel {channel}: Packet complete, received {len(self.payload_bytes[channel])} bytes")
                        
                        # Store the complete packet
                        packet = {
                            "header": {
                                "packet_length": packet_length,
                                "interface_id": interface_id
                            },
                            "payload": bytes(self.payload_bytes[channel])
                        }
                        self.received_packets[channel].append(packet)
                        
                        # Reset for next packet
                        self.header_bytes[channel] = []
                        self.payload_bytes[channel] = []
                        self.state[channel] = "IDLE"

class PacketBufferScoreboard:
    """Verifies correct packet routing and content."""
    def __init__(self):
        self.expected_packets = [[] for _ in range(NUM_CHANNELS)]
    
    def add_expected_packet(self, header, payload, channel):
        """Add an expected packet to the scoreboard."""
        self.expected_packets[channel].append({
            "header": {
                "packet_length": header.packet_length,
                "interface_id": header.interface_id
            },
            "payload": payload
        })
    
    def check_packets(self, received_packets):
        """Check if received packets match the expected ones."""
        for ch in range(NUM_CHANNELS):
            expected = self.expected_packets[ch]
            actual = received_packets[ch]
            
            # Check packet count
            if len(expected) != len(actual):
                log.error(f"Channel {ch}: Expected {len(expected)} packets, got {len(actual)}")
                return False
            
            # Check packet contents
            for i, (exp, act) in enumerate(zip(expected, actual)):
                # Check header
                if exp["header"]["packet_length"] != act["header"]["packet_length"]:
                    log.error(f"Channel {ch}, Packet {i}: Packet length mismatch")
                    return False
                
                if exp["header"]["interface_id"] != act["header"]["interface_id"]:
                    log.error(f"Channel {ch}, Packet {i}: Interface ID mismatch")
                    return False
                
                # Check payload
                if exp["payload"] != act["payload"]:
                    log.error(f"Channel {ch}, Packet {i}: Payload mismatch")
                    return False
            
            log.info(f"Channel {ch}: All {len(expected)} packets verified correctly")
        
        return True

@cocotb.test()
async def test_packet_buffer_basic(dut):
    """Basic test for packet buffer functionality."""
    # Initialize clock
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize driver, monitor, and scoreboard
    driver = PacketBufferDriver(dut, dut.clk_i)
    monitor = PacketBufferMonitor(dut, dut.clk_i)
    scoreboard = PacketBufferScoreboard()
    
    # Set all ready signals to 1
    for ch in range(NUM_CHANNELS):
        setattr(dut, f"m_axis_tready_i_{ch}", 1)
    
    # Reset DUT
    await driver.reset()
    
    # Start monitoring output channels
    await monitor.start_monitoring()
    
    # Allow some time for the monitor to start
    await ClockCycles(dut.clk_i, 10)
    
    # Send a packet to each interface
    for interface_id in range(NUM_CHANNELS):
        header, payload = await driver.send_packet(interface_id=interface_id, fixed_size=64)
        scoreboard.add_expected_packet(header, payload, interface_id)
    
    # Allow time for packets to propagate through the system
    await ClockCycles(dut.clk_i, 200)
    
    # Check if all packets were received correctly
    if not scoreboard.check_packets(monitor.received_packets):
        raise TestFailure("Packet verification failed")
    
    log.info("All packets verified successfully - Test PASSED")

@cocotb.test()
async def test_packet_buffer_flow_control(dut):
    """Test packet buffer with flow control (backpressure)."""
    # Initialize clock
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize driver, monitor, and scoreboard
    driver = PacketBufferDriver(dut, dut.clk_i)
    monitor = PacketBufferMonitor(dut, dut.clk_i)
    scoreboard = PacketBufferScoreboard()
    
    # Set all ready signals to 0 initially (apply backpressure)
    for ch in range(NUM_CHANNELS):
        setattr(dut, f"m_axis_tready_i_{ch}", 0)
    
    # Reset DUT
    await driver.reset()
    
    # Start monitoring output channels
    await monitor.start_monitoring()
    
    # Allow some time for the monitor to start
    await ClockCycles(dut.clk_i, 10)
    
    # Send packets to different interfaces
    test_channels = [0, 3, 7]  # Test a subset of channels
    for idx, interface_id in enumerate(test_channels):
        header, payload = await driver.send_packet(interface_id=interface_id, fixed_size=128)
        scoreboard.add_expected_packet(header, payload, interface_id)
        
        # Wait between packets
        await ClockCycles(dut.clk_i, 20)
    
    # Wait for packets to be buffered
    await ClockCycles(dut.clk_i, 50)
    
    # Now enable ready for each channel one by one
    for ch in test_channels:
        log.info(f"Enabling ready for channel {ch}")
        setattr(dut, f"m_axis_tready_i_{ch}", 1)
        
        # Allow time for packets to be transmitted
        await ClockCycles(dut.clk_i, 50)
        
        # Disable ready again
        setattr(dut, f"m_axis_tready_i_{ch}", 0)
    
    # Check if all packets were received correctly
    if not scoreboard.check_packets(monitor.received_packets):
        raise TestFailure("Packet verification failed with flow control")
    
    log.info("Flow control test passed successfully")

@cocotb.test()
async def test_packet_buffer_max_size(dut):
    """Test packet buffer with maximum size packets."""
    # Initialize clock
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize driver, monitor, and scoreboard
    driver = PacketBufferDriver(dut, dut.clk_i)
    monitor = PacketBufferMonitor(dut, dut.clk_i)
    scoreboard = PacketBufferScoreboard()
    
    # Set all ready signals to 1
    for ch in range(NUM_CHANNELS):
        setattr(dut, f"m_axis_tready_i_{ch}", 1)
    
    # Reset DUT
    await driver.reset()
    
    # Start monitoring output channels
    await monitor.start_monitoring()
    
    # Allow some time for the monitor to start
    await ClockCycles(dut.clk_i, 10)
    
    # Send maximum size packets to different interfaces
    max_packet_size = 1500  # Maximum Ethernet frame size
    test_channels = [1, 4, 6]  # Test a subset of channels
    
    for idx, interface_id in enumerate(test_channels):
        header, payload = await driver.send_packet(interface_id=interface_id, fixed_size=max_packet_size)
        scoreboard.add_expected_packet(header, payload, interface_id)
        
        # Wait between packets
        await ClockCycles(dut.clk_i, 20)
    
    # Allow time for packets to propagate through the system
    await ClockCycles(dut.clk_i, 2000)  # Longer wait for large packets
    
    # Check if all packets were received correctly
    if not scoreboard.check_packets(monitor.received_packets):
        raise TestFailure("Packet verification failed with maximum size packets")
    
    log.info("Maximum packet size test passed successfully")