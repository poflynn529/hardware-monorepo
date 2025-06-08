// PCAP Reader Library
//
// TODO: Add support for PCAPNG, I think this is quite a bit harder with all its variable length fields.

package pcap_pkg;

import utils::*;

typedef struct packed {
    int magic_number;
    shortint version_major;
    shortint version_minor;
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

localparam PCAP_MAGIC_NUMBER = 32'hA1B2C3D4;
localparam STATIC_BUFFER_SIZE_BYTES = 256000;
localparam PCAP_PACKET_HEADER_T_WIDTH = $bits(pcap_packet_header_t) / 8;

class pcap_reader;
    pcap_global_header_t  global_header;
    int                   packet_count;
    int                   file_descriptor;
    bit                   is_little_endian;
    bit                   is_static;

    // Only used if the file is loaded statically. (Some simulators have issues with dynamic memory allocation e.g. xvsim)
    byte                  static_buffer[];
    int                   static_file_length;
    int                   static_file_idx;

    function new(string filename, bit load_static = 0);
        this.file_descriptor = open_file(filename, "rb");
        this.global_header = read_pcap_global_header();
        this.is_static = load_static;

        if (this.is_static == 1) begin
            this.static_buffer = new[STATIC_BUFFER_SIZE_BYTES];
            this.static_file_length = $fread(this.static_buffer, this.file_descriptor);
            this.static_file_idx = 0;

            if (this.static_file_length == STATIC_BUFFER_SIZE_BYTES && $feof(this.file_descriptor) == 0) begin
                $fatal(1, "Error: Static buffer is not large enough to load the PCAP.");
            end
        end
    endfunction

    function automatic pcap_global_header_t read_pcap_global_header();
        pcap_global_header_t global_header;
        int bytes_read;

        bytes_read = $fread(global_header, file_descriptor);

        if (bytes_read != $bits(global_header) / 8) begin
            $fatal(1, "Error: Failed to read PCAP global header");
        end

        // .pcap files may be either little or big endian.
        if(global_header.magic_number == PCAP_MAGIC_NUMBER) begin
            is_little_endian = 0;
        end else if (global_header.magic_number == reverse_byte_endianess(PCAP_MAGIC_NUMBER, $bits(PCAP_MAGIC_NUMBER))) begin
            is_little_endian = 1;
            global_header = byte_swap_global_header(global_header);
        end else begin
            $fatal(1, "Error: Invalid PCAP magic number");
        end

        return global_header;
    endfunction

    function automatic void print_pcap_global_header();
        $display("[INFO] PCAP Global Header:");
        $display("[INFO] Magic Number:  %0h", this.global_header.magic_number);
        $display("[INFO] Version Major: %0d", this.global_header.version_major);
        $display("[INFO] Version Minor: %0d", this.global_header.version_minor);
        $display("[INFO] This Zone:     %0d", this.global_header.thiszone);
        $display("[INFO] Sig Figs:      %0d", this.global_header.sigfigs);
        $display("[INFO] Snap Length:   %0d", this.global_header.snaplen);
        $display("[INFO] Network:       %0d", this.global_header.network);
    endfunction

    function automatic pcap_global_header_t byte_swap_global_header(pcap_global_header_t global_header);
        global_header.magic_number  = reverse_byte_endianess(global_header.magic_number,  $bits(global_header.magic_number));
        global_header.version_major = reverse_byte_endianess(global_header.version_major, $bits(global_header.version_major));
        global_header.version_minor = reverse_byte_endianess(global_header.version_minor, $bits(global_header.version_minor));
        global_header.thiszone      = reverse_byte_endianess(global_header.thiszone,      $bits(global_header.thiszone));
        global_header.sigfigs       = reverse_byte_endianess(global_header.sigfigs,       $bits(global_header.sigfigs));
        global_header.snaplen       = reverse_byte_endianess(global_header.snaplen,       $bits(global_header.snaplen));
        global_header.network       = reverse_byte_endianess(global_header.network,       $bits(global_header.network));
        return global_header;
    endfunction

    function automatic pcap_packet_header_t byte_swap_pcap_packet_header(pcap_packet_header_t packet_header);
        packet_header.ts_sec   = reverse_byte_endianess(packet_header.ts_sec,   $bits(packet_header.ts_sec));
        packet_header.ts_usec  = reverse_byte_endianess(packet_header.ts_usec,  $bits(packet_header.ts_usec));
        packet_header.incl_len = reverse_byte_endianess(packet_header.incl_len, $bits(packet_header.incl_len));
        packet_header.orig_len = reverse_byte_endianess(packet_header.orig_len, $bits(packet_header.orig_len));
        return packet_header;
    endfunction

    function automatic bit get_next_packet(ref byte buffer[]);
        int bytes_read;
        pcap_packet_header_t packet_header;
        byte packet_header_temp_array[];

        if (this.is_static) begin
            if (this.static_file_idx == this.static_file_length) begin
                return 0;
            end else if (this.static_file_idx > this.static_file_length) begin
                $fatal(1, "Possible truncation or incorrect parsing of PCAP file.");
            end

            this.packet_count++;

            packet_header_temp_array = new[PCAP_PACKET_HEADER_T_WIDTH];
            copy_byte_array(this.static_buffer, packet_header_temp_array, this.static_file_idx, 0, PCAP_PACKET_HEADER_T_WIDTH);
            packet_header = pcap_packet_header_t'({>>byte{packet_header_temp_array}});
            if (this.is_little_endian) packet_header = byte_swap_pcap_packet_header(packet_header);
            
            buffer = new[packet_header.incl_len];
            this.static_file_idx += (PCAP_PACKET_HEADER_T_WIDTH);
            copy_byte_array(this.static_buffer, buffer, this.static_file_idx, 0, packet_header.incl_len);
            
            this.static_file_idx += + packet_header.incl_len;
        end else begin
            
            // xelab 2024.1 segfaults with this code. TODO Test with Questa.
            `ifdef XILINX_SIMULATOR
                $fatal(1, "Xilinx Simulator does not support dynamic file reading.");
            `else
                if ($feof(file_descriptor)) return 0;
                this.packet_count++;

                bytes_read = $fread(packet_header, this.file_descriptor);
                if (bytes_read != PCAP_PACKET_HEADER_T_WIDTH) begin
                    $fatal(1, "Error: Failed to read PCAP packet header");
                end

                if (this.is_little_endian) packet_header = byte_swap_pcap_packet_header(packet_header);
                
                buffer = new[packet_header.incl_len];

                bytes_read = $fread(buffer, this.file_descriptor);
                if (bytes_read != packet_header.incl_len) begin
                    $fatal(1, "Error: Failed to read packet data at packet %0d", packet_count);
                end
            `endif
        end

        return 1;
    endfunction

endclass

endpackage
