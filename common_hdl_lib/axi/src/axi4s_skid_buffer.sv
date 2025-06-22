// Insert a register slice to an AXI4Stream while maintaining the valid-ready handshake.

module axi4s_skid_buffer #(
    parameter AXI_WIDTH = 64
)(
    input  logic                   clk_i,
    input  logic                   rst_i,

    // Upstream (Master Side)
    input  logic [AXI_WIDTH - 1:0] m_tdata_i,
    input  logic                   m_tvalid_i,
    output logic                   m_tready_o,
    input  logic                   m_tlast_i,
    
    // Downstream (Slave Side)
    output logic [AXI_WIDTH - 1:0] s_tdata_o,
    output logic                   s_tvalid_o,
    input  logic                   s_tready_i,
    output logic                   s_tlast_o
);

    logic                   skid_valid_r;
    logic [AXI_WIDTH - 1:0] skid_data_r;
    logic                   buffer_valid_r;
    logic [AXI_WIDTH - 1:0] buffer_data_r;

    assign m_tready_o = !skid_valid_r;
    
    // Buffer process
    always @(posedge clk_i) begin
        if (m_tvalid_i && m_tready_o) begin
            buffer_data_r  <= m_tdata_i;
            buffer_valid_r <= 1;
        end else if (skid_valid_r) begin
            buffer_valid_r <= 1;
        end else begin
            buffer_valid_r <= 0;
        end

        if (rst_i) begin
            buffer_valid_r <= 0;
        end
    end

    // Skid process
    always @(posedge clk_i) begin

        // Move data from buffer to skid if downstream stalls
        if (!s_tready_i && !skid_valid_r) begin
            skid_data_r  <= buffer_data_r;
            skid_valid_r <= buffer_valid_r;
        end else if (s_tready_i && skid_valid_r) begin
            skid_valid_r <= 0;
        end

        if (rst_i) begin
            skid_valid_r <= 0;
        end
    end

    // Mux between buffer & skid
    assign s_tvalid_o = skid_valid_r || buffer_valid_r;
    assign s_tdata_o  = skid_valid_r ? skid_data_r : buffer_data_r;
    
endmodule
