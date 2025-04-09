module vector_muxcy #(
    parameter NUM_INPUTS,
    parameter INPUT_WIDTH,
    parameter COMPARE_MODE = "MIN",   // TODO: Implement "MAX"
    parameter IF_EQUAL_MODE = "FIRST" // TODO: Implement "LAST"
)(
    input  logic [INPUT_WIDTH - 1:0]         data_i [NUM_INPUTS - 1:0],
    output logic [$clog2(NUM_INPUTS) - 1:0] muxcy_o
);
    logic [INPUT_WIDTH - 1:0] best_level_w;

    always_comb begin
        best_level_w = (2 ** INPUT_WIDTH) - 1;

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (data_i[i] < best_level_w) begin
                best_level_w = data_i[i];
                muxcy_o = i;
            end
        end
    end

endmodule