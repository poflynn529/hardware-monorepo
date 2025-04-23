`ifndef PACKET_BUFFER_SCOREBOARD_SVH
`define PACKET_BUFFER_SCOREBOARD_SVH

import packet_buffer_pkg::*;

class packet_buffer_scoreboard;
    localparam NUM_CHANNELS = 8;
    
    // Dynamic queues to store packets for each channel
    byte expect_queue[NUM_CHANNELS][$];
    byte actual_queue[NUM_CHANNELS][$];
    int packets_checked;
    int packets_failed;
    
    function new();
        packets_checked = 0;
        packets_failed = 0;
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            expect_queue[i] = {};
            actual_queue[i] = {};
        end
    endfunction
    
    // Add packet to expect queue for specified channel
    function void add_expect_packet(byte packet[], int channel);
        if (channel >= NUM_CHANNELS) begin
            `ERROR($sformatf("Invalid channel %0d specified for expect packet", channel));
            return;
        end
        
        byte expect_pkt[];
        expect_pkt = new[packet.size()];
        for (int i = 0; i < packet.size(); i++) begin
            expect_pkt[i] = packet[i];
        end
        
        expect_queue[channel].push_back(expect_pkt);
        
        `DEBUG($sformatf("Added expect packet of length %0d to channel %0d", packet.size(), channel));
    endfunction
    
    // Add packet to actual queue for specified channel
    function void add_actual_packet(byte packet[], int channel);
        if (channel >= NUM_CHANNELS) begin
            `ERROR($sformatf("Invalid channel %0d specified for actual packet", channel));
            return;
        end
        
        byte actual_pkt[];
        actual_pkt = new[packet.size()];
        for (int i = 0; i < packet.size(); i++) begin
            actual_pkt[i] = packet[i];
        end
        
        actual_queue[channel].push_back(actual_pkt);
        
        `DEBUG($sformatf("Added actual packet of length %0d to channel %0d", packet.size(), channel));
        
        // Automatically check the queue if we have packets to compare
        check_packets(channel);
    endfunction
    
    // Check if the expected and actual packets match for a given channel
    function void check_packets(int channel);
        if (channel >= NUM_CHANNELS) begin
            `ERROR($sformatf("Invalid channel %0d specified for packet check", channel));
            return;
        end
        
        if (expect_queue[channel].size() > 0 && actual_queue[channel].size() > 0) begin
            byte expect[];
            byte actual[];
            bit match = 1;
            
            expect = expect_queue[channel].pop_front();
            actual = actual_queue[channel].pop_front();
            
            if (expect.size() != actual.size()) begin
                `ERROR($sformatf("Packet size mismatch on channel %0d: expected %0d bytes, got %0d bytes", 
                    channel, expect.size(), actual.size()));
                match = 0;
            end else begin
                for (int i = 0; i < expect.size(); i++) begin
                    if (expect[i] != actual[i]) begin
                        `ERROR($sformatf("Packet data mismatch on channel %0d at byte %0d: expected 0x%02x, got 0x%02x", 
                            channel, i, expect[i], actual[i]));
                        match = 0;
                        break;
                    end
                end
            end
            
            packets_checked++;
            
            if (match) begin
                `INFO($sformatf("Packet on channel %0d verified successfully", channel));
            end else begin
                packets_failed++;
                `ERROR($sformatf("Packet verification failed on channel %0d", channel));
            end
        end
    endfunction
    
    // Report statistics at end of simulation
    function void report();
        int queued_packets = 0;
        
        `INFO($sformatf("Scoreboard Report:"));
        `INFO($sformatf("  Packets checked: %0d", packets_checked));
        `INFO($sformatf("  Packets passed:  %0d", packets_checked - packets_failed));
        `INFO($sformatf("  Packets failed:  %0d", packets_failed));
        
        // Check for any packets still in the queues
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            if (expect_queue[i].size() > 0) begin
                `WARN($sformatf("Channel %0d has %0d expected packets still queued", i, expect_queue[i].size()));
                queued_packets += expect_queue[i].size();
            end
            if (actual_queue[i].size() > 0) begin
                `WARN($sformatf("Channel %0d has %0d actual packets still queued", i, actual_queue[i].size()));
                queued_packets += actual_queue[i].size();
            end
        end
        
        if (queued_packets > 0) begin
            `WARN($sformatf("Total of %0d packets still queued and not checked", queued_packets));
        end
    endfunction
    
endclass

`endif // PACKET_BUFFER_SCOREBOARD_SVH