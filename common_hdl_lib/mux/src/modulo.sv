// Baseline: let the synthesiser decide how to implement %.
module modulo_naive #(
    parameter int DATA_WIDTH = 8,
    parameter int MODULUS    = 7
) (
    input  logic [DATA_WIDTH-1:0]       data_i,
    output logic [$clog2(MODULUS)-1:0]  data_o
);

    assign data_o = data_i % MODULUS;

endmodule

// Barrett reduction: replaces x % C with a multiply-shift-correct sequence
// whose magic constant is fully resolved at elaboration time.
//
// t = floor(x * magic / 2^k)  ≈  floor(x / C)  (exact or one low)
// r = x - t * C                                  (= x%C or x%C + C)
// if r >= C: r -= C
//
// Constraints: 2 <= MODULUS < 2^DATA_WIDTH, DATA_WIDTH <= 63.
module modulo_barrett #(
    parameter int DATA_WIDTH = 8,
    parameter int MODULUS    = 7
) (
    input  logic [DATA_WIDTH-1:0]       data_i,
    output logic [$clog2(MODULUS)-1:0]  data_o
);

    // {1'b1, DATA_WIDTH zeros} = 2^DATA_WIDTH, exact regardless of DATA_WIDTH.
    localparam logic [DATA_WIDTH:0]   TWO_K = {1'b1, {DATA_WIDTH{1'b0}}};
    localparam logic [DATA_WIDTH-1:0] MAGIC = TWO_K / MODULUS;

    generate
        if ((MODULUS & (MODULUS - 1)) == 0) begin : gen_pow2
            assign data_o = data_i[$clog2(MODULUS)-1:0];

        end else begin : gen_barrett
            logic [2*DATA_WIDTH-1:0] product_w;
            logic [DATA_WIDTH-1:0]   quotient_w;
            logic [DATA_WIDTH-1:0]   remainder_w;

            assign product_w   = {{DATA_WIDTH{1'b0}}, data_i} *
                                  {{DATA_WIDTH{1'b0}}, MAGIC};
            assign quotient_w  = product_w[2*DATA_WIDTH-1:DATA_WIDTH];
            assign remainder_w = data_i - quotient_w * MODULUS;

            assign data_o = (remainder_w >= MODULUS) ? remainder_w - MODULUS
                                                     : remainder_w;
        end
    endgenerate

endmodule
