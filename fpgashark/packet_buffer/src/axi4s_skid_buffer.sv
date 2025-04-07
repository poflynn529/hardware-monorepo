// Insert a register slice to an AXI4Stream while maintaining the valid-ready handshake.

module axi4s_skid_buffer #(
    parameter AXI_WIDTH
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

    assign m_tready_o = !buffer_valid_r || !skid_valid_r || s_tready_i;
    
    always @(posedge clk_i) begin
        if (s_tready_i && m_tvalid_i) begin
            buffer_data_r  <= m_tdata_i;
            buffer_valid_r <= 1'b1;
        end
            
        // Move data from buffer to skid if downstream stalls
        if (!s_tready_i && s_tvalid_o) begin
            skid_data_r    <= buffer_data_r;
            skid_valid_r   <= buffer_valid_r;
            buffer_valid_r <= 1'b0;
        end else if (s_tready_i) begin
            skid_valid_r <= 1'b0;
        end

        if (rst_i) begin
            buffer_valid_r <= 1'b0;
            skid_valid_r   <= 1'b0;
        end
    end
 
    assign s_tvalid_o = skid_valid_r || buffer_valid_r;
    assign s_tdata_o  = skid_valid_r ? skid_data_r : buffer_data_r;
    
endmodule