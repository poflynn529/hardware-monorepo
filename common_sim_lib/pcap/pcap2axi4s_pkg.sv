// Simulation only module to send a pcap as an AXI4Stream.

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
