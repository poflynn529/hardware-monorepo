`timescale 1ns/1ps

// Alternative implementation: compile this file instead of fifo.sv.
module fifo #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH = 512
) (
    input  logic clk,
    input  logic rst,
    input  logic wr_valid,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic wr_ready,
    output logic rd_valid,
    output logic [DATA_WIDTH-1:0] rd_data,
    input  logic rd_ready,
    output logic [$clog2(DEPTH+1)-1:0] count,
    output logic almost_full
);
    localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;

    logic [DATA_WIDTH-1:0] memory [DEPTH-1:0];
    logic [PTR_WIDTH-1:0] head;
    logic [PTR_WIDTH-1:0] tail;
    logic [PTR_WIDTH-1:0] next_tail;
    logic wr;
    logic rd;

    assign wr = wr_valid && wr_ready;
    assign rd = rd_valid && rd_ready;
    assign next_tail = (int'(tail) == DEPTH - 1) ? '0 : tail + 1'b1;

    always_ff @(posedge clk) begin
        if (rst) begin
            head <= '0;
        end else if (wr) begin
            memory[head] <= wr_data;
            if (int'(head) == DEPTH - 1)
                head <= '0;
            else
                head <= head + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst)
            tail <= '0;
        else if (rd)
            tail <= next_tail;
    end

    always_ff @(posedge clk) begin
        if (rst)
            count <= '0;
        else if (wr && !rd)
            count <= count + 1'b1;
        else if (rd && !wr)
            count <= count - 1'b1;
    end

    // The current front word is already in rd_data. Fetch its successor
    // at the consuming edge; forward writes that become the new front.
    always_ff @(posedge clk) begin
        if (!rst) begin
            if (wr && ((int'(count) == 0) || ((int'(count) == 1) && rd)))
                rd_data <= wr_data;
            else if (rd && (int'(count) > 1))
                rd_data <= memory[next_tail];
        end
    end

    assign almost_full = (int'(count) == DEPTH - 1);
    assign wr_ready = (int'(count) != DEPTH);
    assign rd_valid = (int'(count) != 0);
endmodule
