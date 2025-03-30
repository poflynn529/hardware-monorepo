/**
 * PCAP Package - Contains definitions for PCAP file format structures
 *
 * This package defines the structures and constants related to the PCAP
 * (Packet Capture) file format, which is commonly used for network packet capture.
 */
package packet_buffer_pkg;

typedef struct packed {
    logic [15:0] packet_length;
    logic [15:0] interface_id;
} packet_header_t;

localparam PACKET_HEADER_T_WIDTH = 32;
localparam MAX_PACKET_LENGTH     = 1500;

function automatic packet_header_t unpack(input logic [PACKET_HEADER_T_WIDTH-1:0] header_vector);
    packet_header_t header;
    
    header.packet_length = header_vector[15:0];
    header.interface_id  = header_vector[31:16];
    
    return header;
endfunction

endpackage