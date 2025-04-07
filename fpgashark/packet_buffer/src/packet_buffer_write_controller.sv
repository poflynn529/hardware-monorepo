// Packet Buffer Write Controller
// 
// This module tracks the fill level of multiple FIFOs and selects the FIFO with the
// lowest fill level for writing data.
// 
// It parses the message header to determine how many AXI transactions are in the packet
// and will ensure that the entire packet is written to the same FIFO.

`include "macros.svh"

import packet_buffer_pkg::*;

module packet_buffer_write_controller #(
    parameter NUM_LANES,
    parameter HEADER_WIDTH,
    parameter AXI_WIDTH,
    parameter MAX_PACKET_LENGTH,
    parameter FIFO_DEPTH,
    parameter LANE_SELECT_IDX_WIDTH
)(
    input  logic                               clk_i,
    input  logic                               rst_i,

    input  packet_header_t                     header_i,
    input  logic                               input_valid_i,
    input  logic                               input_last_i,

    input  logic                               output_ready_i [NUM_LANES - 1:0],
    input  logic                               output_valid_i [NUM_LANES - 1:0],

    output logic                               input_ready_o,
    output logic [LANE_SELECT_IDX_WIDTH - 1:0] lane_sel_o,
    output logic                               lane_wr_valid_o
);

    localparam AXI_TRANSACTIONS_COUNTER_WIDTH = $clog2(MAX_PACKET_LENGTH / AXI_WIDTH);
    localparam FIFO_FILL_LEVEL_COUNTER_WIDTH  = $clog2(FIFO_DEPTH * 8);

    logic [FIFO_FILL_LEVEL_COUNTER_WIDTH - 1:0]  fifo_fill_level_r [NUM_LANES - 1:0];
    logic [AXI_TRANSACTIONS_COUNTER_WIDTH - 1:0] axi_transactions_counter_r;
    logic [LANE_SELECT_IDX_WIDTH - 1:0]          lane_sel_idx_w;
    logic [LANE_SELECT_IDX_WIDTH - 1:0]          lane_sel_idx_r;
    logic                                        lane_wr_valid_r;
    logic                                        input_ready_r;

    // Find the FIFO with minimum fill level that can still accept the packet.
    function automatic logic[0:0][NUM_LANES - 1:0] find_min_lane();
        logic [LANE_SELECT_IDX_WIDTH - 1:0]         min_lane  = 0;
        logic [FIFO_FILL_LEVEL_COUNTER_WIDTH - 1:0] min_level = FIFO_DEPTH * 8;

        for (int i = 0; i < NUM_LANES; i++) begin
            if (fifo_fill_level_r[i] < min_level) begin
                min_level = fifo_fill_level_r[i];
                min_lane = i;
            end
        end
        
        return min_lane;
    endfunction

    assign lane_sel_o      = lane_sel_idx_r;
    assign lane_wr_valid_o = lane_wr_valid_r;
    assign input_ready_o   = input_ready_r;
    assign lane_sel_idx_w  = find_min_lane();

    // Lane selection cannot be updated when a write is in progress.
    always @(posedge clk_i) begin
        if (axi_transactions_counter_r == 0) begin
            lane_sel_idx_r <= lane_sel_idx_w;
        end

        if (fifo_fill_level_r[lane_sel_idx_w] < FIFO_DEPTH) begin
            lane_wr_valid_r <= input_valid_i;
            input_ready_r   <= 1'b1;
        end else begin
            lane_wr_valid_r <= 1'b0;
            input_ready_r   <= 1'b0;
        end
    end
    
    // Track the levels of the FIFOs.
    always @(posedge clk_i) begin
        if (input_valid_i && input_ready_r) begin
            fifo_fill_level_r[lane_sel_idx_r] <= fifo_fill_level_r[lane_sel_idx_r] + 8;
            if (axi_transactions_counter_r == 0) begin
                axi_transactions_counter_r <= cdiv(header_i.packet_length, AXI_WIDTH / 8);
            end else begin
                axi_transactions_counter_r <= axi_transactions_counter_r - 1;
            end
        end
        
        for (int i = 0; i < NUM_LANES; i++) begin
            if (output_valid_i[i] && output_ready_i[i]) begin
                if (fifo_fill_level_r[i] > 0) begin // TODO: Add an assertion here to check this case.
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