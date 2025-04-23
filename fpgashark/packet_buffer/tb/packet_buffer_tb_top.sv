// Packet Buffer Testbench Top
// 
// This testbench instantiates the packet_buffer module and tests it using
// PCAP files converted to AXI4-Stream transactions.
// 

`include "macros.svh"
`include "packet_buffer_monitor.svh"
`include "packet_buffer_scoreboard.svh"

import utils::*;
import pcap_pkg::*;
import packet_buffer_pkg::*;

module packet_buffer_tb_top;
    
    localparam AXI_WIDTH = 64;
    localparam OUTPUT_WIDTH = 8;
    localparam NUM_LANES = AXI_WIDTH / OUTPUT_WIDTH;
    localparam CLK_PERIOD = 10;
    localparam FILENAME = "/home/poflynn/src/hardware-monorepo/.data/packet_buffer_top_tb/test_pcap.pcap";
    
    logic clk;
    logic rst;

    logic [AXI_WIDTH - 1:0] s_tdata;
    logic                   s_tvalid;
    logic                   s_tready;
    logic                   s_tlast;

    logic [AXI_WIDTH - 1:0] tdata;
    logic                   tvalid;
    logic                   tready;
    logic                   tlast;
    
    logic [OUTPUT_WIDTH - 1:0] pkt_tdata_o[NUM_LANES];
    logic                      pkt_tvalid_o[NUM_LANES];
    logic                      pkt_tready_i[NUM_LANES];

    packet_header_t header;
    pcap_reader     reader;
    byte            packet_buffer[];
    byte            header_buffer[];
    
    packet_buffer_scoreboard scoreboard;
    packet_buffer_monitor    monitor;
    
    interface monitor_if;
        logic clk;
        logic rst;
        logic [OUTPUT_WIDTH-1:0] pkt_tdata[NUM_LANES];
        logic pkt_tvalid[NUM_LANES];
        logic pkt_tready[NUM_LANES];
    endinterface
    
    monitor_if mon_if();
    
    // Connect the monitor interface to the DUT signals
    assign mon_if.clk = clk;
    assign mon_if.rst = rst;
    
    generate
        for (genvar i = 0; i < NUM_LANES; i++) begin : g_mon_if_connect
            assign mon_if.pkt_tdata[i] = pkt_tdata_o[i];
            assign mon_if.pkt_tvalid[i] = pkt_tvalid_o[i];
            assign mon_if.pkt_tready[i] = pkt_tready_i[i];
        end
    endgenerate
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        for (int i = 0; i < NUM_LANES; i++) begin
            pkt_tready_i[i] = 1; // Set all ready signals to 1 by default
        end
        
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        sim_timeout(clk, 200);
    end
    
    initial begin
        scoreboard = new();
        monitor = new(mon_if, scoreboard);
        monitor.run();
    end
    
    initial begin
        s_tdata = 0;
        s_tvalid = 0;
        s_tlast = 0;

        repeat (10) @(posedge clk);

        reader = new(FILENAME, 1);
        reader.print_pcap_global_header();
        
        while (reader.get_next_packet(packet_buffer)) begin
            int channel;
            
            // Create header with packet length and interface ID
            header.packet_length = packet_buffer.size();
            
            // Calculate which channel this packet should go to based on a simple hash
            // Using modulo to distribute packets across channels 
            channel = reader.packet_count % NUM_LANES;
            header.interface_id = channel;
            
            // Add the expected packet to the scoreboard for verification
            scoreboard.add_expect_packet(packet_buffer, channel);
            
            // Pack header into byte array
            pack_dynamic_byte_array(header, header_buffer);
            
            `INFO($sformatf("Sending packet #%0d with %0d bytes to channel %0d.", 
                  reader.packet_count, packet_buffer.size(), channel));
                  
            // Send the packet to the DUT
            packet2axi4s(
                .clk(clk),
                .rst(rst),
                .tdata(s_tdata),
                .tlast(s_tlast),
                .tvalid(s_tvalid),
                .tready(s_tready),
                .packet(packet_buffer),
                .header(header_buffer)
            );

            // Random delay between packets
            repeat($urandom_range(0, 20)) @(posedge clk);
        end

        // Allow time for processing to complete
        repeat(100) @(posedge clk);
        
        // Print scoreboard report
        scoreboard.report();

        `INFO($sformatf("Completed processing %0d packets from %s", reader.packet_count, FILENAME));
        $finish();
    end

    packet_buffer #(
        .AXI_WIDTH(AXI_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),
        
        .tdata_i(tdata),
        .tvalid_i(tvalid),
        .tlast_i(tlast),
        .tready_o(tready),
        
        .pkt_tdata_o(pkt_tdata_o),
        .pkt_tvalid_o(pkt_tvalid_o),
        .pkt_tready_i(pkt_tready_i)
    );

    always @(posedge clk) begin
        tdata    <= s_tdata;
        tvalid   <= s_tvalid;
        tlast    <= s_tlast;
        s_tready <= tready;
    end

    task automatic packet2axi4s(
        ref       logic                   clk,
        ref       logic                   rst,
        ref       logic [AXI_WIDTH - 1:0] tdata,
        ref       logic                   tlast,
        ref       logic                   tvalid,
        const ref logic                   tready,
        input     byte                    packet[],
        input     byte                    header[]
    );
        byte buffer[]           = new[packet.size() + header.size()];
        int  num_axi_words_left = cdiv(buffer.size() * 8, AXI_WIDTH);
        int  buffer_idx         = 0;

        `DEBUG($sformatf("Packet Length w/ Header: %d", buffer.size()));
        `DEBUG($sformatf("Number of AXI words req: %d", num_axi_words_left));

        copy_byte_array(header, buffer, 0, 0, header.size());
        copy_byte_array(packet, buffer, 0, header.size(), packet.size());

        `DEBUG($sformatf("Buffer: %s", byte_array_to_hex_string(buffer)));

        while (num_axi_words_left != 0) begin
            @(posedge clk);
            tvalid = 1;
            tlast  = 0;
            if (num_axi_words_left == 1) tlast = 1;
            
            // Copy buffer to the AXI word with zero padding if required.
            for (int i = 0; i < AXI_WIDTH / 8; i++) begin
                if (i >= buffer.size()) begin
                    tdata[(((AXI_WIDTH / 8) - i) * 8) - 1 -: 8] = 8'h00;
                end else begin
                    tdata[(((AXI_WIDTH / 8) - i) * 8) - 1 -: 8] = buffer[i + buffer_idx];
                end
            end

            if (tready == 1 && rst == 0) begin
                buffer_idx += AXI_WIDTH / 8;
                num_axi_words_left--;
            end
        end

        @(posedge clk)
        tvalid = 0;
        tlast  = 0;
    endtask

endmodule
