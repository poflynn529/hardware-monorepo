`ifndef PACKET_BUFFER_MONITOR_SVH
`define PACKET_BUFFER_MONITOR_SVH

import packet_buffer_pkg::*;

class packet_buffer_monitor;
    localparam OUTPUT_WIDTH = 8;
    localparam NUM_CHANNELS = 8;
    
    virtual interface {
        logic clk;
        logic rst;
        logic [OUTPUT_WIDTH-1:0] pkt_tdata[NUM_CHANNELS];
        logic pkt_tvalid[NUM_CHANNELS];
        logic pkt_tready[NUM_CHANNELS];
    } monitor_if;
    
    packet_buffer_scoreboard scoreboard;
    
    enum {
        IDLE,
        COLLECT_HEADER,
        COLLECT_PAYLOAD
    } state[NUM_CHANNELS];
    
    byte header_buffer[NUM_CHANNELS][PACKET_HEADER_T_WIDTH_BYTES];
    int header_byte_count[NUM_CHANNELS];
    packet_header_t packet_header[NUM_CHANNELS];
    
    byte packet_buffer[NUM_CHANNELS][];
    int packet_byte_count[NUM_CHANNELS];
    
    function new(virtual interface {
        logic clk;
        logic rst;
        logic [OUTPUT_WIDTH-1:0] pkt_tdata[NUM_CHANNELS];
        logic pkt_tvalid[NUM_CHANNELS];
        logic pkt_tready[NUM_CHANNELS];
    } intf, packet_buffer_scoreboard sb);
        monitor_if = intf;
        scoreboard = sb;
        
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            state[i] = IDLE;
            header_byte_count[i] = 0;
            packet_byte_count[i] = 0;
        end
    endfunction
    
    task run();
        fork
            for (int ch = 0; ch < NUM_CHANNELS; ch++) begin
                automatic int channel = ch;
                fork
                    monitor_channel(channel);
                join_none
            end
        join_none
    endtask
    
    task monitor_channel(int channel);
        `INFO($sformatf("Starting monitor for channel %0d", channel));
        
        forever begin
            @(posedge monitor_if.clk);
            
            if (monitor_if.rst) begin
                state[channel] = IDLE;
                header_byte_count[channel] = 0;
                packet_byte_count[channel] = 0;
                continue;
            end
            
            // Only sample when valid and ready are both high
            if (monitor_if.pkt_tvalid[channel] && monitor_if.pkt_tready[channel]) begin
                case (state[channel])
                    IDLE: begin
                        // First byte of a new packet - should be the header
                        header_buffer[channel][0] = monitor_if.pkt_tdata[channel];
                        header_byte_count[channel] = 1;
                        state[channel] = COLLECT_HEADER;
                        `DEBUG($sformatf("Channel %0d: Started collecting header", channel));
                    end
                    
                    COLLECT_HEADER: begin
                        // Collect header bytes
                        header_buffer[channel][header_byte_count[channel]] = monitor_if.pkt_tdata[channel];
                        header_byte_count[channel]++;
                        
                        // If we have the complete header, extract the packet length 
                        if (header_byte_count[channel] == PACKET_HEADER_T_WIDTH_BYTES) begin
                            // Reconstruct the header
                            packet_header[channel].packet_length = {header_buffer[channel][0], header_buffer[channel][1]};
                            packet_header[channel].interface_id = {header_buffer[channel][2], header_buffer[channel][3]};
                            
                            // Allocate buffer for the packet data
                            packet_buffer[channel] = new[packet_header[channel].packet_length];
                            packet_byte_count[channel] = 0;
                            
                            `DEBUG($sformatf("Channel %0d: Header complete, packet length = %0d, interface_id = %0d", 
                                channel, packet_header[channel].packet_length, packet_header[channel].interface_id));
                            
                            state[channel] = COLLECT_PAYLOAD;
                        end
                    end
                    
                    COLLECT_PAYLOAD: begin
                        // Collect packet data
                        packet_buffer[channel][packet_byte_count[channel]] = monitor_if.pkt_tdata[channel];
                        packet_byte_count[channel]++;
                        
                        // If we've collected the entire packet
                        if (packet_byte_count[channel] == packet_header[channel].packet_length) begin
                            `INFO($sformatf("Channel %0d: Packet complete, length = %0d bytes", 
                                channel, packet_header[channel].packet_length));
                            
                            // Add packet to scoreboard
                            scoreboard.add_actual_packet(packet_buffer[channel], channel);
                            
                            // Reset for next packet
                            state[channel] = IDLE;
                            header_byte_count[channel] = 0;
                            packet_byte_count[channel] = 0;
                        end
                    end
                endcase
            end
        end
    endtask
    
endclass

`endif // PACKET_BUFFER_MONITOR_SVH