// Insert a register slice to an AXI4Stream while maintaining the valid-ready handshake.

module axi4s_skid_buffer #(
    parameter AXI_WIDTH = 64
)(
    input  logic                       clk_i,
    input  logic                       rst_i,

    // Upstream (Master Side)
    input  logic [AXI_WIDTH - 1:0]     m_tdata_i,
    input  logic                       m_tvalid_i,
    output logic                       m_tready_o,
    input  logic                       m_tlast_i,
    input  logic [AXI_WIDTH / 8 - 1:0] m_tkeep_i,
    
    // Downstream (Slave Side)
    output logic [AXI_WIDTH - 1:0]     s_tdata_o,
    output logic                       s_tvalid_o,
    input  logic                       s_tready_i,
    output logic                       s_tlast_o,
    output logic [AXI_WIDTH / 8 - 1:0] s_tkeep_o
);
    logic                       skid_valid_r;
    logic [AXI_WIDTH - 1:0]     skid_tdata_r;
    logic                       skid_tlast_r;
    logic [AXI_WIDTH / 8 - 1:0] skid_tkeep_r;

    logic                       buffer_valid_r;
    logic [AXI_WIDTH - 1:0]     buffer_tdata_r;
    logic                       buffer_tlast_r;
    logic [AXI_WIDTH / 8 - 1:0] buffer_tkeep_r;

    assign m_tready_o = !skid_valid_r;
    
    // Buffer process
    always @(posedge clk_i) begin
        if (m_tvalid_i && m_tready_o) begin
            buffer_tdata_r <= m_tdata_i;
            buffer_tlast_r <= m_tlast_i;
            buffer_tkeep_r <= m_tkeep_i;
            buffer_valid_r <= 1;
        end else if (skid_valid_r) begin
            buffer_valid_r <= 1;
        end else begin
            buffer_valid_r <= 0;
            buffer_tlast_r <= 0;
        end

        if (rst_i) begin
            buffer_valid_r <= 0;
        end
    end

    // Skid process
    always @(posedge clk_i) begin

        // Move data from buffer to skid if downstream stalls
        if (!s_tready_i && !skid_valid_r) begin
            skid_tdata_r <= buffer_tdata_r;
            skid_tlast_r <= buffer_tlast_r;
            skid_tkeep_r <= buffer_tkeep_r;
            skid_valid_r <= buffer_valid_r;
        end else if (s_tready_i && skid_valid_r) begin
            skid_valid_r <= 0;
            skid_tlast_r <= 0;
        end

        if (rst_i) begin
            skid_valid_r <= 0;
            skid_tlast_r <= 0;
        end
    end

    // Mux between buffer & skid
    assign s_tvalid_o = skid_valid_r || buffer_valid_r;

    assign s_tdata_o  = skid_valid_r ? skid_tdata_r : buffer_tdata_r;
    assign s_tlast_o  = skid_valid_r ? skid_tlast_r : buffer_tlast_r;
    assign s_tkeep_o  = skid_valid_r ? skid_tkeep_r : buffer_tkeep_r;
    
endmodule
