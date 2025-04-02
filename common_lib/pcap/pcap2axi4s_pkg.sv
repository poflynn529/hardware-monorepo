// Simulation only module to send a pcap as an AXI4Stream.

module packet2axi4s(
    parameter AXI_WIDTH = 64
) (
    input  logic                   clk,
    input  logic                   rst,

    output logic [AXI_WIDTH - 1:0] tdata,
    output logic                   tlast,
    output logic                   tvalid,
    input  logic                   tready,
);
byte buffer[]           = new[packet_length + header_length];
int  num_axi_words_left = cdiv((buffer.size() * 8), AXI_WIDTH);
int  buffer_idx         = 0;

copy_byte_array(header, buffer, 0, header_length);
copy_byte_array(packet, buffer, header_length, packet_length);

while (num_axi_words_left != 0) begin
    @(posedge clk);
    tvalid = 1;
    tlast = 0;
    if (num_axi_words_left == 1) tlast = 1;
    
    // Copy buffer to the AXI word with zero padding if required.
    `INFO($sformatf("buffer_idx: %d", buffer_idx));
    for (int i = buffer_idx; i < buffer_idx + AXI_WIDTH / 8; i++) begin
        if (i >= buffer.size()) begin
            tdata[i * 8 +: 8] = 8'h00;
        end else begin
            tdata[i * 8 +: 8] = buffer[i];
        end
    end

    if (tready == 1 && rst == 0) begin
        // `INFO("Word transfered. Decrementing...");
        buffer_idx += AXI_WIDTH / 8;
        num_axi_words_left--;
    end
end

@(posedge clk)
tvalid = 0;

endmodule