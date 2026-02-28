module modulo_harness #(
    parameter int DATA_WIDTH = 8,
    parameter int MODULUS    = 7
) (
    input  logic [DATA_WIDTH-1:0]       data_i,
    output logic [$clog2(MODULUS)-1:0]  naive_o,
    output logic [$clog2(MODULUS)-1:0]  barrett_o
);

    modulo_naive #(
        .DATA_WIDTH(DATA_WIDTH),
        .MODULUS(MODULUS)
    ) u_naive (
        .data_i(data_i),
        .data_o(naive_o)
    );

    modulo_barrett #(
        .DATA_WIDTH(DATA_WIDTH),
        .MODULUS(MODULUS)
    ) u_barrett (
        .data_i(data_i),
        .data_o(barrett_o)
    );

endmodule
