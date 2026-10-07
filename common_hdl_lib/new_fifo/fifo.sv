`timescale 1ns/1ps

module fifo #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH      = 512
) (
    input  logic                         clk,
    input  logic                         rst,

    input  logic                         wr_valid,
    input  logic [DATA_WIDTH-1:0]        wr_data,
    output logic                         wr_ready,

    output logic                         rd_valid,
    output logic [DATA_WIDTH-1:0]        rd_data,
    input  logic                         rd_ready,

    output logic [$clog2(DEPTH+1) - 1:0] count,
    output logic                         almost_full
);

logic [DATA_WIDTH - 1:0] memory [DEPTH - 1:0];

logic rd;
logic wr;

logic [DATA_WIDTH - 1:0] buffer;
logic [DATA_WIDTH - 1:0] skid;

logic buffer_valid;
logic skid_valid;

logic [$clog2(DEPTH) - 1:0] head;
logic [$clog2(DEPTH) - 1:0] tail;

assign wr = wr_valid && wr_ready;
assign rd = rd_valid && rd_ready;

always_ff @(posedge clk) begin
    if (rst) begin
        head <= 0;
    end else if (wr) begin
        memory[head] <= wr_data;
        if (int'(head) == DEPTH - 1) begin
            head <= 0;
        end else begin
            head <= head + 1;
        end
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        tail <= 0;
    end else if (rd) begin
        if (int'(tail) == DEPTH - 1) begin
            tail <= 0;
        end else begin
            tail <= tail + 1;
        end
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        count <= 0;
    end else if (wr && !rd) begin
        count <= count + 1;
    end else if (rd && !wr) begin
        count <= count - 1;
    end
end

always_ff @(posedge clk) begin
    if ((int'(count) == 0) && wr) begin
        buffer <= wr_data;
    end else begin
        buffer <= memory[tail];
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        buffer_valid <= 0;
    end else begin
        buffer_valid <= !((int'(count) == 0) || ((int'(count) == 1) && rd));
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        skid_valid <= 0;
    end else begin
        if (!rd && buffer_valid) begin
            skid <= buffer;
            skid_valid <= 1;
        end else begin
            skid_valid <= 0;
        end
    end
end

assign almost_full = (int'(count) == DEPTH - 1);
assign wr_ready = !(int'(count) == DEPTH);
assign rd_valid = (int'(count) != 0);
assign rd_data = skid_valid ? skid : buffer;

endmodule
