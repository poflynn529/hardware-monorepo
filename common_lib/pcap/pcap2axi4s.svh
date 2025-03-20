/**
 * PCAP to AXI4-Stream Conversion Library
 *
 * Simulation tasks for converting PCAP files to AXI4-Stream transactions.
 * It provides functionality to read packet data from a PCAP file and transmit it over an AXI4-Stream interface.
 */

`ifndef __PCAP2AXI4S_SVH__
`define __PCAP2AXI4S_SVH__

localparam PCAP_MAGIC_NUMBER = 32'hA1B2C3D4;

typedef struct packed {
    int magic_number;
    short version_major;
    short version_minor;
    int thiszone;
    int sigfigs;
    int snaplen;
    int network;
} pcap_global_header_t;

typedef struct packed {
    int ts_sec;
    int ts_usec;
    int incl_len;
    int orig_len;
} pcap_packet_header_t;

class pcap_reader;
    pcap_global_header_t  global_header;
    int                   packet_count;
    int                   file_descriptor;
    bit                   is_little_endian;

    function new(string filename);
        this.file_descriptor = read_file(filename);
        this.global_header = read_pcap_global_header();
    endfunction

    function automatic pcap_global_header_t read_pcap_global_header();
        pcap_global_header_t global_header;
        int bytes_read;

        bytes_read = $fread(global_header, file_descriptor);

        if (bytes_read != $bits(global_header)/8) begin
            $fatal("Error: Failed to read PCAP global header");
        end

        // .pcap files may be either little or big endian.
        if(global_header.magic_number == PCAP_MAGIC_NUMBER) begin
            is_little_endian = 0;
        end else if (global_header.magic_number == reverse_bytes(PCAP_MAGIC_NUMBER)) begin
            is_little_endian = 1;
            global_header = byte_swap_global_header(global_header);
        end else begin
            $fatal("Error: Invalid PCAP magic number");
        end

        return global_header;
    endfunction

    function automatic void print_pcap_global_header();
        $display("[INFO] PCAP Global Header:");
        $display("[INFO] Magic Number: %h",  this.global_header.magic_number);
        $display("[INFO] Version Major: %d", this.global_header.version_major);
        $display("[INFO] Version Minor: %d", this.global_header.version_minor);
        $display("[INFO] This Zone: %d",     this.global_header.thiszone);
    endfunction

    function automatic global_header byte_swap_global_header(global_header_t global_header);
        global_header.magic_number  = reverse_bytes(global_header.magic_number);
        global_header.version_major = reverse_bytes(global_header.version_major);
        global_header.version_minor = reverse_bytes(global_header.version_minor);
        global_header.thiszone      = reverse_bytes(global_header.thiszone);
        return global_header;
    endfunction

    function automatic pcap_packet_header_t byte_swap_pcap_packet_header(pcap_packet_header_t packet_header);
        packet_header.ts_sec   = reverse_bytes(packet_header.ts_sec);
        packet_header.ts_usec  = reverse_bytes(packet_header.ts_usec);
        packet_header.incl_len = reverse_bytes(packet_header.incl_len);
        packet_header.orig_len = reverse_bytes(packet_header.orig_len);
        return packet_header;
    endfunction

    function automatic bit get_next_packet(ref byte buffer[], ref int buffer_length);
        int bytes_read;
        pcap_packet_header_t packet_header;

        if ($feof(file_descriptor)) begin
            return 0;
        end

        this.packet_count++;
        bytes_read = $fread(packet_header, this.file_descriptor);
        if (bytes_read != $bits(pcap_packet_header_t) / 8) begin
            $fatal("Error: Failed to read PCAP packet header");
        end

        if (is_little_endian) begin
            packet_header = byte_swap_pcap_packet_header(packet_header);
        end
        
        buffer_length = packet_header.incl_len;
        buffer = new[buffer_length];
        
        bytes_read = $fread(buffer, this.file_descriptor, 0, buffer_length);
        if (bytes_read != buffer_length) begin
            $fatal("Error: Failed to read packet data at packet %0d", packet_count);
        end

        return 1;
    endfunction

endclass

task automatic send_pcap_axi4s(
    ref   logic              clk,
    ref   logic              rst_n,
    ref   logic [63:0]       tdata,
    ref   logic              tlast,
    ref   logic              tvalid,
    ref   logic              tready,
    input int                random_wait_percentage,
    input int                inter_packet_idle_cycles = 0,
    input int                inter_beat_gap = 0,
    input int                interface_id = 0,
    input string             filename
); 
    int                   current_packet_length;
    int                   packet_count;  
    packet_header_t       axi_header;
    pcap_reader           reader;
    int                   buffer_length;
    byte                  buffer[];
    
    reader = new(filename);

    while (reader.get_next_packet(buffer, buffer_length)) begin
        
        axi_header.packet_length = buffer_length;
        axi_header.interface_id = interface_id;
        
        $display("[INFO] Sending packet #%0d with %0d bytes.", reader.packet_count, buffer_length);

    end
    
    $display("[DEBUG] Completed processing %0d packets from %s", reader.packet_count, filename);
endtask

// task automatic void send_packet_axi4s(
//     ref   logic              clk,
//     ref   logic              rst_n,
//     ref   logic [63:0]       tdata,
//     ref   logic              tlast,
//     ref   logic              tvalid,
//     ref   logic              tready,
//             // Add idle cycles between packets if requested and not the first packet
// if (idle_cycles > 0 && packet_count > 0) begin
//     tvalid = 1'b0;
//     for (cycles_waited = 0; cycles_waited < idle_cycles; cycles_waited++) begin
//         @(posedge clk);
//     end
// end

// // Send the header first
// tvalid = 1'b1;
// tdata = {axi_header.packet_length, axi_header.interface_id, 32'h0}; // Pad to 64 bits
// tkeep = 8'hF; // First 4 bytes valid
// tlast = 1'b0;

// // Wait for ready signal
// while (tready !== 1'b1) @(posedge clk);
// @(posedge clk);

// // Add inter-beat gap if specified
// if (inter_beat_gap > 0) begin
//     tvalid = 1'b0;
//     repeat (int'(inter_beat_gap)) @(posedge clk);
// end

// // Send packet data in 8-byte chunks
// remaining_bytes = total_bytes;
// for (int i = 0; i < total_bytes; i += 8) begin
//     // Determine number of valid bytes in this beat
//     int valid_bytes = (remaining_bytes >= 8) ? 8 : remaining_bytes;
    
//     // Set tkeep mask based on valid bytes
//     tkeep = 8'h0;
//     for (int j = 0; j < valid_bytes; j++) begin
//         tkeep[j] = 1'b1;
//     end
    
//     // Set data (clear unused bytes to avoid X's in simulation)
//     tdata = 64'h0;
//     for (int j = 0; j < valid_bytes; j++) begin
//         tdata[j*8 +: 8] = buffer[i+j];
//     end
    
//     // Set tlast on final beat
//     tlast = (i + 8 >= total_bytes) ? 1'b1 : 1'b0;
//     tvalid = 1'b1;
    
//     // Wait for ready signal
//     while (tready !== 1'b1) @(posedge clk);
//     @(posedge clk);
    
//     // Add inter-beat gap if specified and not last beat
//     if (inter_beat_gap > 0 && !tlast) begin
//         tvalid = 1'b0;
//         repeat (int'(inter_beat_gap)) @(posedge clk);
//     end
    
//     remaining_bytes -= valid_bytes;
// end

// // Reset signals after packet
// tvalid = 1'b0;
// tlast = 1'b0;
// endtask

`endif // __PCAP2AXI4S_SVH__
