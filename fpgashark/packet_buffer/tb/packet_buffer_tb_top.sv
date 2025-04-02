/**
 * Packet Buffer Testbench Top
 *
 * This testbench instantiates the packet_buffer module and tests it using
 * PCAP files converted to AXI4-Stream transactions.
 */

`include "macros.svh"

import utils::*;
import pcap_pkg::*;
import packet_buffer_pkg::*;

module packet_buffer_tb_top;
    
    localparam AXI_WIDTH = 64;
    localparam OUTPUT_WIDTH = 8;
    localparam NUM_LANES = AXI_WIDTH / OUTPUT_WIDTH;
    localparam CLK_PERIOD = 10;
    localparam FILENAME = ".data/packet_buffer_top_tb/test_pcap.pcap";
    
    logic clk;
    logic rst;

    logic [AXI_WIDTH - 1:0] s_tdata;
    logic                   s_tvalid;
    logic                   s_tready;
    logic                   s_tlast;
    logic [7:0]             s_tkeep;
    
    logic [OUTPUT_WIDTH - 1:0] pkt_tdata_o[NUM_LANES];
    logic                      pkt_tvalid_o[NUM_LANES];
    logic                      pkt_tready_i[NUM_LANES];

    packet_header_t header;
    pcap_reader     reader;
    byte            packet_buffer[];
    byte            header_buffer[];
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        sim_timeout(clk, 200);
    end

    initial begin
        s_tdata = 0;
        s_tvalid = 0;
        s_tlast = 0;

        repeat (10) @(posedge clk);

        reader = new(FILENAME, 1);
        reader.print_pcap_global_header();

        while (reader.get_next_packet(packet_buffer)) begin
            
            header.packet_length = packet_buffer.size();
            header.interface_id  = 10;
            pack_dynamic_byte_array(header, header_buffer);
            
            `INFO($sformatf("Sending packet #%0d with %0d bytes.", reader.packet_count, packet_buffer.size()));
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

            repeat($urandom_range(0, 20)) @(posedge clk);
        end

        repeat(25) @(posedge clk);

        `INFO($sformatf("Completed processing %0d packets from %s", reader.packet_count, FILENAME));
        $finish();
    end
    
    packet_buffer #(
        .AXI_WIDTH(AXI_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),
        
        .tdata_i(s_tdata),
        .tvalid_i(s_tvalid),
        .tready_o(s_tready),
        
        .pkt_tdata_o(pkt_tdata_o),
        .pkt_tvalid_o(pkt_tvalid_o),
        .pkt_tready_i(pkt_tready_i)
    );

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
        tlast = 0;
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
            //`INFO("Word transfered. Decrementing...");
            buffer_idx += AXI_WIDTH / 8;
            num_axi_words_left--;
        end
    end

    @(posedge clk)
    tvalid = 0;
    tlast = 0;

    endtask

endmodule 