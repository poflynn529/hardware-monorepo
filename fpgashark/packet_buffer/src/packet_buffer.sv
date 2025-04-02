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

    // Packet Buffer Interface
    output logic [OUTPUT_WIDTH - 1:0] pkt_tdata_o[AXI_WIDTH / OUTPUT_WIDTH],
    output logic                      pkt_tvalid_o[AXI_WIDTH / OUTPUT_WIDTH],
    input  logic                      pkt_tready_i[AXI_WIDTH / OUTPUT_WIDTH]
);

localparam NUM_BUFFER_LANES      = AXI_WIDTH / OUTPUT_WIDTH;
localparam LANE_SELECT_IDX_WIDTH = $clog2(NUM_BUFFER_LANES);

logic [AXI_WIDTH - 1:0] tdata_r;
logic                   tvalid_r;

logic [OUTPUT_WIDTH - 1:0]          lane_data_r[NUM_BUFFER_LANES];
logic                               lane_read_en_w[NUM_BUFFER_LANES-1:0];
logic                               lane_write_en_w[NUM_BUFFER_LANES-1:0];
logic [LANE_SELECT_IDX_WIDTH - 1:0] lane_sel_idx_w;

always_ff @(posedge clk_i) begin
    if (tvalid_i && tready_o) begin
        tdata_r <= tdata_i;
        tvalid_r <= 1'b1;
    end

    if (rst_i) begin
        tdata_r <= '0;
        tvalid_r <= 1'b0;
    end
end

always_comb begin
    for (int i = 0; i < NUM_BUFFER_LANES; i++) begin
        lane_write_en_w[i] = tvalid_i && tready_o;
        lane_read_en_w[i] = pkt_tready_i[i];
    end
end

packet_buffer_write_controller #(
    .NUM_LANES(NUM_BUFFER_LANES),
    .HEADER_WIDTH(PACKET_HEADER_T_WIDTH),
    .AXI_WIDTH(AXI_WIDTH),
    .MAX_PACKET_LENGTH(MAX_ETH_FRAME_LENGTH),
    .FIFO_DEPTH(500),
    .LANE_SELECT_IDX_WIDTH(LANE_SELECT_IDX_WIDTH)
) write_controller_i (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .header_i(unpack(tdata_r[PACKET_HEADER_T_WIDTH - 1:0])),
    .input_valid_i(tvalid_i),
    .output_ready_i(pkt_tready_i),
    .output_valid_i(pkt_tvalid_o),
    .input_ready_o(tready_o),
    .lane_sel_o(lane_sel_idx_w)
);

generate
    for (genvar i = 0; i < NUM_BUFFER_LANES; i++) begin : g_buffer_lanes
        
        fifo36e2_wrapper #(
            .WRITE_WIDTH(AXI_WIDTH),
            .WRITE_PARITY_WIDTH(8),
            .READ_WIDTH(OUTPUT_WIDTH),
            .READ_PARITY_WIDTH(1),
            .CLOCK_DOMAIN("COMMON")
        ) fifo_inst (
            .clk_i(clk_i),
            .rst_i(rst_i),
            .write_en_i(lane_write_en_w[i]),
            .read_en_i(lane_read_en_w[i]),
            .data_i(tdata_r),
            .data_o(lane_data_r[i])
        );

        always_comb begin
            // Only extract the relevant bytes from the 64-bit output
            pkt_tdata_o[i] = lane_data_r[i][OUTPUT_WIDTH-1:0];
        end
    end
endgenerate

endmodule