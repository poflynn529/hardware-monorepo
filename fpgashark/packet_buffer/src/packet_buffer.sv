module packet_buffer #(
    parameter AXI_WIDTH = 64,
    parameter OUTPUT_WIDTH = 8,
) (
    input  logic                      clk_i,
    input  logic                      rst_i,
   
    // AXI4-Stream Slave Interface
    input  logic [AXI_WIDTH - 1:0]    tdata_i,
    input  logic                      tvalid_i,
    output logic                      tready_o,

    // Packet Buffer Interface
    output logic [OUTPUT_WIDTH - 1:0] pkt_tdata_o[AXI_WIDTH / OUTPUT_WIDTH],
    output logic                      pkt_tvalid_o,
    input  logic                      pkt_tready_i
);

localparam NUM_BUFFER_LANES = AXI_WIDTH / OUTPUT_WIDTH;

logic [AXI_WIDTH - 1:0] tdata_r;
logic                   tvalid_r;

logic [OUTPUT_WIDTH - 1:0] lane_data_r[NUM_BUFFER_LANES];
logic                      lane_read_en_w[NUM_BUFFER_LANES-1:0];
logic                      lane_write_en_w[NUM_BUFFER_LANES-1:0];
logic                      lane_write_sel_w;

always_ff @(posedge clk_i) begin
    if (rst_i) begin
        tdata_reg <= '0;
        tvalid_reg <= 1'b0;
    end else if (tvalid_i && tready_o) begin
        tdata_reg <= tdata_i;
        tvalid_reg <= 1'b1;
    end else if (pkt_tready_i) begin
        tvalid_reg <= 1'b0;
    end
end

always_comb begin
    for (int i = 0; i < NUM_BUFFER_LANES; i++) begin
        lane_write_en[i] = tvalid_i && tready_o;
        lane_read_en[i] = pkt_tready_i && !lane_empty[i];
    end
end

packet_buffer_write_controller #(
    .INPUT_WIDTH(AXI_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) write_controller_i (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .header_i(tdata_r[AXI_WIDTH-1:0]),
    .input_ready_i(tready_o),
    .input_valid_i(tvalid_i),
    .output_ready_i(pkt_tready_i),
    .output_valid_i(pkt_tvalid_o),
    .lane_sel_o(lane_write_sel_w),
);

generate
    for (genvar i = 0; i < NUM_BUFFER_LANES; i++) begin : g_buffer_lanes
        
        fifo36e2_wrapper #(
            .WRITE_WIDTH(OUTPUT_WIDTH),
            .WRITE_PARITY_WIDTH(0),
            .READ_WIDTH(OUTPUT_WIDTH),
            .READ_PARITY_WIDTH(0),
            .CLOCK_DOMAIN("COMMON")
        ) fifo_inst (
            .clk_i(clk_i),
            .rst_i(rst_i),
            .write_en_i(lane_write_en[i]),
            .read_en_i(lane_read_en[i]),
            .data_i(tdata_reg),
            .data_o(lane_data_out[i])
        );

        always_comb begin
            // Only extract the relevant bytes from the 64-bit output
            pkt_tdata_o[i] = lane_data_out[i][OUTPUT_WIDTH-1:0];
        end
    end
endgenerate

// Pass valid signal directly to output
assign pkt_tvalid_o = tvalid_reg;

endmodule