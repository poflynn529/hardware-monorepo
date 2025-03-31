/**
 * Packet Buffer Testbench Top
 *
 * This testbench instantiates the packet_buffer module and tests it using
 * PCAP files converted to AXI4-Stream transactions.
 */

import pcap_pkg::*;
import packet_buffer_pkg::*;

module packet_buffer_tb_top;
    
    localparam AXI_WIDTH = 64;
    localparam OUTPUT_WIDTH = 8;
    localparam NUM_LANES = AXI_WIDTH / OUTPUT_WIDTH;
    localparam CLK_PERIOD = 10; // 10ns = 100MHz
    
    logic clk;
    logic rst;
    
    // AXI4-Stream signals (input to DUT)
    logic [AXI_WIDTH-1:0] s_tdata;
    logic                 s_tvalid;
    logic                 s_tready;
    logic                 s_tlast;
    logic [7:0]           s_tkeep;
    
    // Packet Buffer output signals
    logic [OUTPUT_WIDTH-1:0] pkt_tdata_o[NUM_LANES];
    logic                    pkt_tvalid_o[NUM_LANES];
    logic                    pkt_tready_i[NUM_LANES];
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Reset generation
    initial begin
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
    end

    initial begin
        repeat (10) @(posedge clk);

        send_pcap_axi4s(
            // .clk(clk),
            // .rst(rst),
            // .tdata(s_tdata),
            // .tlast(s_tlast),
            // .tvalid(s_tvalid),
            // .tready(s_tready),
            // .random_wait_percentage(0),
            // .inter_packet_idle_cycles(0),
            // .inter_beat_gap(0),
            // .interface_id(0),
            .filename(".data/packet_buffer_top_tb/test_pcap.pcap")
        );
    end
    
    // Instantiate the DUT
    packet_buffer #(
        .AXI_WIDTH(AXI_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),
        
        // AXI4-Stream input
        .tdata_i(s_tdata),
        .tvalid_i(s_tvalid),
        .tready_o(s_tready),
        
        // Packet Buffer output
        .pkt_tdata_o(pkt_tdata_o),
        .pkt_tvalid_o(pkt_tvalid_o),
        .pkt_tready_i(pkt_tready_i)
    );

    task automatic send_pcap_axi4s(
        // ref       logic              clk,
        // ref       logic              rst,
        // ref       logic [63:0]       tdata,
        // ref       logic              tlast,
        // ref       logic              tvalid,
        // ref       logic              tready,
        // input     int                random_wait_percentage,
        // input     int                inter_packet_idle_cycles = 0,
        // input     int                inter_beat_gap = 0,
        // input     int                interface_id = 0, Probably not these fields, looks like its the loop.
        input     string             filename
    ); 
        int                   current_packet_length;
        int                   packet_count;  
        packet_header_t       axi_header;
        pcap_reader           reader;
        int                   buffer_length;
        byte                  buffer[];

        reader = new(filename, 1);
        reader.print_pcap_global_header();

        while (reader.get_next_packet(buffer, buffer_length)) begin
            
            // axi_header.packet_length = buffer_length;
            // axi_header.interface_id = interface_id;
            
            $display("[INFO] Sending packet #%0d with %0d bytes.", reader.packet_count, buffer_length);
            wait(1);

        end
        
        $display("[DEBUG] Completed processing %0d packets from %s", reader.packet_count, filename);
        $finish();
    endtask


endmodule 