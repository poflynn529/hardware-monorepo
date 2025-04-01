// Packet Buffer Write Controller
// 
// This module tracks the fill level of multiple FIFOs and selects the FIFO with the
// lowest fill level for writing data.
// 
// It parses the message header to determine how many AXI transactions are in the packet
// and will ensure that the entire packet is written to the same FIFO.

import packet_buffer_pkg::*;

module packet_buffer_write_controller #(
    parameter NUM_LANES,
    parameter HEADER_WIDTH,
    parameter AXI_WIDTH,
    parameter MAX_PACKET_LENGTH,
    parameter FIFO_DEPTH,
    parameter LANE_SELECT_IDX_WIDTH
)(
    input  logic           clk_i,
    input  logic           rst_i,

    input  logic           input_valid_i,
    input  packet_header_t header_i,

    input  logic           output_ready_i [NUM_LANES - 1:0],
    input  logic           output_valid_i [NUM_LANES - 1:0],

    output logic           input_ready_o,
    output logic [LANE_SELECT_IDX_WIDTH - 1:0]          lane_sel_o
);

    localparam AXI_TRANSACTIONS_COUNTER_WIDTH = $clog2(MAX_PACKET_LENGTH / AXI_WIDTH);
    localparam FIFO_FILL_LEVEL_COUNTER_WIDTH  = $clog2(FIFO_DEPTH * 8);

    logic [FIFO_FILL_LEVEL_COUNTER_WIDTH - 1:0]  fifo_fill_level_r [NUM_LANES - 1:0];
    logic [AXI_TRANSACTIONS_COUNTER_WIDTH - 1:0] axi_transactions_counter_r;
    logic [LANE_SELECT_IDX_WIDTH - 1:0]          lane_sel_idx_r;


    assign lane_sel_o = lane_sel_idx_r;
    assign input_ready_o = 1;
    
    // Find the FIFO with minimum fill level that can still accept the packet.
    function automatic logic[0:0][NUM_LANES - 1:0] find_min_lane();
        logic [LANE_SELECT_IDX_WIDTH - 1:0]         min_lane  = 0;
        logic [FIFO_FILL_LEVEL_COUNTER_WIDTH - 1:0] min_level = 0;

        for (int i = 0; i < NUM_LANES; i++) begin
            if (fifo_fill_level_r[i] < min_level) begin
                min_level = fifo_fill_level_r[i];
                min_lane = i;
            end
        end
        
        return min_lane;
    endfunction

    // Ensure that the lane selection is updated only after the complete packet has been received.
    always @(posedge clk_i) begin
        if (axi_transactions_counter_r == 0) begin
            lane_sel_idx_r <= find_min_lane();
        end
    end
    
    always @(posedge clk_i) begin

        if (input_valid_i && input_ready_o) begin
            fifo_fill_level_r[lane_sel_idx_r] <= fifo_fill_level_r[lane_sel_idx_r] + 8;
            if (axi_transactions_counter_r == 0) begin
                axi_transactions_counter_r <= (header_i.packet_length + (AXI_WIDTH / 8) - 1) / (AXI_WIDTH / 8); // TODO: Refactor this to use a common function.
            end else begin
                axi_transactions_counter_r <= axi_transactions_counter_r - 1;
            end
        end
        
        for (int i = 0; i < NUM_LANES; i++) begin
            if (output_valid_i[i] && output_ready_i[i]) begin
                if (fifo_fill_level_r[i] > 0) begin // TODO: Add a system error check here for this case.
                    fifo_fill_level_r[i] <= fifo_fill_level_r[i] - 1;
                end
            end
        end

        if (rst_i) begin
            for (int i = 0; i < NUM_LANES; i++) begin
                fifo_fill_level_r[i] <= 0;
            end
            axi_transactions_counter_r <= 0;
        end
    end

endmodule 