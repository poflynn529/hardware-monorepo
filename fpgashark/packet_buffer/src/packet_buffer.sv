import packet_buffer_pkg::*;

module packet_buffer #(
    parameter AXI_WIDTH = 64,
    parameter OUTPUT_WIDTH = 8
) (
    input  logic                      clk_i,
    input  logic                      rst_i,
   
    // AXI4-Stream Slave Interface
    input  logic [AXI_WIDTH - 1:0]    tdata_i,
    input  logic                      tvalid_i,
    output logic                      tready_o,
    input  logic                      tlast_i,

    // Packet Buffer Interface
    output logic [OUTPUT_WIDTH - 1:0] pkt_tdata_o[AXI_WIDTH / OUTPUT_WIDTH],
    output logic                      pkt_tvalid_o[AXI_WIDTH / OUTPUT_WIDTH],
    input  logic                      pkt_tready_i[AXI_WIDTH / OUTPUT_WIDTH]
);

localparam NUM_BUFFER_LANES      = AXI_WIDTH / OUTPUT_WIDTH;
localparam LANE_SELECT_IDX_WIDTH = $clog2(NUM_BUFFER_LANES);

logic [AXI_WIDTH - 1:0] tdata_buffered_w;
logic                   tvalid_buffered_w;
logic                   tready_w;
logic                   tlast_buffered_w;

logic [AXI_WIDTH - 1:0] tdata_r;

logic [OUTPUT_WIDTH - 1:0]          lane_data_w [NUM_BUFFER_LANES];
logic [OUTPUT_WIDTH - 1:0]          fifo_empty_w [NUM_BUFFER_LANES];
logic                               lane_read_en_w [NUM_BUFFER_LANES];
logic                               lane_write_en_w [NUM_BUFFER_LANES];
logic                               lane_skid_ready_w [NUM_BUFFER_LANES];
logic [LANE_SELECT_IDX_WIDTH - 1:0] lane_sel_idx_w;
logic                               lane_sel_valid_w;

// Register data on input to the module.
axi4s_skid_buffer #(
    .AXI_WIDTH (AXI_WIDTH)
) axi4s_skid_buffer_i (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    // Upstream (Master Side)
    .m_tdata_i  (tdata_i),
    .m_tvalid_i (tvalid_i),
    .m_tready_o (tready_o),
    .m_tlast_i  (tlast_i),

    // Downstream (Slave Side)
    .s_tdata_o  (tdata_buffered_w),
    .s_tvalid_o (tvalid_buffered_w),
    .s_tready_i (tready_w),
    .s_tlast_o  (tlast_buffered_w)
);

packet_buffer_write_controller #(
    .NUM_LANES             (NUM_BUFFER_LANES),
    .HEADER_WIDTH          (PACKET_HEADER_T_WIDTH),
    .AXI_WIDTH             (AXI_WIDTH),
    .MAX_PACKET_LENGTH     (MAX_ETH_FRAME_LENGTH),
    .FIFO_DEPTH            (500),
    .LANE_SELECT_IDX_WIDTH (LANE_SELECT_IDX_WIDTH)
) write_controller_i (
    .clk_i            (clk_i),
    .rst_i            (rst_i),
    .header_i         (unpack(tdata_buffered_w[AXI_WIDTH - 1:AXI_WIDTH - PACKET_HEADER_T_WIDTH])),
    .input_valid_i    (tvalid_buffered_w),
    .input_last_i     (tlast_buffered_w),
    .output_ready_i   (pkt_tready_i),
    .output_valid_i   (pkt_tvalid_o),
    .input_ready_o    (tready_w),
    .lane_sel_o       (lane_sel_idx_w),
    .lane_sel_valid_o (lane_sel_valid_w)
);

// Register the data again while the write controller decides where to send it.
always @(posedge clk_i) begin
    tdata_r <= tdata_buffered_w;
end

always_comb begin
    for (int i = 0; i < NUM_BUFFER_LANES; i++) begin
        lane_write_en_w[i] = 0;
    end

    if (lane_sel_valid_w) lane_write_en_w[lane_sel_idx_w] = 1;
end

generate
    for (genvar i = 0; i < NUM_BUFFER_LANES; i++) begin : g_buffer_lanes
        
        assign lane_read_en_w[i] = !fifo_empty_w[i] && lane_skid_ready_w[i];

        fifo36e2_wrapper #(
            .WRITE_WIDTH(AXI_WIDTH),
            .WRITE_PARITY_WIDTH(8),
            .READ_WIDTH(OUTPUT_WIDTH),
            .READ_PARITY_WIDTH(1),
            .CLOCK_DOMAIN("COMMON")
        ) fifo_i (
            .clk_i(clk_i),
            .rst_i(rst_i),
            .write_en_i(lane_write_en_w[i]),
            .read_en_i(lane_read_en_w[i]),
            .data_i(tdata_r),
            .data_o(lane_data_w[i]),
            .empty_o(fifo_empty_w[i])
        );

        // Register egress data from the FIFOs.
        axi4s_skid_buffer #(
            .AXI_WIDTH (OUTPUT_WIDTH)
        ) axi4s_skid_buffer_i (
            .clk_i      (clk_i),
            .rst_i      (rst_i),

            // Upstream (Master Side)
            .m_tdata_i  (lane_data_w[i][OUTPUT_WIDTH-1:0]),
            .m_tvalid_i (!fifo_empty_w[i]),
            .m_tready_o (lane_skid_ready_w[i]),
            .m_tlast_i  (0),

            // Downstream (Slave Side)
            .s_tdata_o  (pkt_tdata_o[i]),
            .s_tvalid_o (pkt_tvalid_o[i]),
            .s_tready_i (pkt_tready_i[i]),
            .s_tlast_o  ()
        );

    end
endgenerate

endmodule