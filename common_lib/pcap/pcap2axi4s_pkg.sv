package pcap2axi4s;

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

endpackage