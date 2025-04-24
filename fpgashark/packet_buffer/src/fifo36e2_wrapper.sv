
module fifo36e2_wrapper #(
    parameter WRITE_WIDTH = 64,
    parameter WRITE_PARITY_WIDTH = 8,
    parameter READ_WIDTH  = 8,
    parameter READ_PARITY_WIDTH = 1,
    parameter CLOCK_DOMAIN = "INDEPENDENT"

) (
    input  logic                     clk_i,     
    input  logic                     rst_i,     
    input  logic                     write_en_i,
    input  logic                     read_en_i, 
    input  logic [WRITE_WIDTH - 1:0] data_i,    
    output logic [READ_WIDTH - 1:0]  data_o,
    output logic                     empty_o
);

    logic [63:0] dout;

    assign data_o = dout[READ_WIDTH -1:0];

    FIFO36E2 #(
        .CASCADE_ORDER("NONE"),                        // Not using cascading
        .CLOCK_DOMAINS("INDEPENDENT"),                 // Separate read and write clocks
        .EN_ECC_PIPE("FALSE"),                         // No ECC pipeline
        .EN_ECC_READ("FALSE"),                         // No ECC on read
        .EN_ECC_WRITE("FALSE"),                        // No ECC on write
        .FIRST_WORD_FALL_THROUGH("FALSE"),             // Standard FIFO behavior
        .INIT(72'h000000000000000000),                 // Initialize output to zeros
        .PROG_EMPTY_THRESH(256),                       // Programmable empty threshold
        .PROG_FULL_THRESH(256),                        // Programmable full threshold
        .IS_RDCLK_INVERTED(1'b0),                      // No clock inversion
        .IS_RDEN_INVERTED(1'b0),                       // No read enable inversion
        .IS_RSTREG_INVERTED(1'b0),                     // No register reset inversion
        .IS_RST_INVERTED(1'b0),                        // No reset inversion
        .IS_WRCLK_INVERTED(1'b0),                      // No write clock inversion
        .IS_WREN_INVERTED(1'b0),                       // No write enable inversion
        .RDCOUNT_TYPE("RAW_PNTR"),                     // Raw read pointer
        .READ_WIDTH(READ_WIDTH + READ_PARITY_WIDTH),   // Configurable read width
        .REGISTER_MODE("UNREGISTERED"),                // No output registers
        .RSTREG_PRIORITY("RSTREG"),                    // Reset priority
        .SLEEP_ASYNC("FALSE"),                         // Synchronous sleep
        .SRVAL(72'h000000000000000000),                // Reset value
        .WRCOUNT_TYPE("RAW_PNTR"),                     // Raw write pointer
        .WRITE_WIDTH(WRITE_WIDTH + WRITE_PARITY_WIDTH) // Configurable write width
    ) 
    FIFO36E2_inst (
        // Cascade Signals outputs: Multi-FIFO cascade signals - not connected
        .CASDOUT(),                   // 64-bit output: Data cascade output bus
        .CASDOUTP(),                  // 8-bit output: Parity data cascade output bus
        .CASNXTEMPTY(),               // 1-bit output: Cascade next empty
        .CASPRVRDEN(),                // 1-bit output: Cascade previous read enable
        
        // ECC Signals outputs: Error Correction Circuitry ports - not used
        .DBITERR(),                   // 1-bit output: Double bit error status
        .ECCPARITY(),                 // 8-bit output: Generated error correction parity
        .SBITERR(),                   // 1-bit output: Single bit error status
        
        // Read Data outputs: Read output data
        .DOUT(dout),                // 64-bit output: FIFO data output bus
        .DOUTP(),                     // 8-bit output: FIFO parity output bus - not used
        
        // Status outputs: Flags and other FIFO status outputs
        .EMPTY(empty_o),              // 1-bit output: Empty
        .FULL(),                      // 1-bit output: Full
        .PROGEMPTY(),                 // 1-bit output: Programmable empty - not used
        .PROGFULL(),                  // 1-bit output: Programmable full - not used
        .RDCOUNT(),                   // 14-bit output: Read count - not used
        .RDERR(),                     // 1-bit output: Read error - not used
        .RDRSTBUSY(),                 // 1-bit output: Reset busy (sync to RDCLK) - not used
        .WRCOUNT(),                   // 14-bit output: Write count - not used
        .WRERR(),                     // 1-bit output: Write Error - not used
        .WRRSTBUSY(),                 // 1-bit output: Reset busy (sync to WRCLK) - not used
        
        // Cascade Signals inputs: Multi-FIFO cascade signals - nulled out
        .CASDIN(64'b0),               // 64-bit input: Data cascade input bus
        .CASDINP(8'b0),               // 8-bit input: Parity data cascade input bus
        .CASDOMUX(1'b0),              // 1-bit input: Cascade MUX select input
        .CASDOMUXEN(1'b0),            // 1-bit input: Enable for cascade MUX select
        .CASNXTRDEN(1'b0),            // 1-bit input: Cascade next read enable
        .CASOREGIMUX(1'b0),           // 1-bit input: Cascade output MUX select
        .CASOREGIMUXEN(1'b0),         // 1-bit input: Cascade output MUX select enable
        .CASPRVEMPTY(1'b1),           // 1-bit input: Cascade previous empty
        
        // ECC Signals inputs: Error Correction Circuitry ports - nulled out
        .INJECTDBITERR(1'b0),         // 1-bit input: Inject a double-bit error
        .INJECTSBITERR(1'b0),         // 1-bit input: Inject a single bit error
        
        // Read Control Signals inputs: Read clock, enable and reset input signals
        .RDCLK(clk_i),                // 1-bit input: Read clock
        .RDEN(read_en_i),             // 1-bit input: Read enable
        .REGCE(1'b1),                 // 1-bit input: Output register clock enable
        .RSTREG(1'b0),                // 1-bit input: Output register reset
        .SLEEP(1'b0),                 // 1-bit input: Sleep Mode
        
        // Write Control Signals inputs: Write clock and enable input signals
        .RST(rst_i),                  // 1-bit input: Reset
        .WRCLK(clk_i),                // 1-bit input: Write clock
        .WREN(write_en_i),            // 1-bit input: Write enable
        
        // Write Data inputs: Write input data
        .DIN(data_i),                 // 64-bit input: FIFO data input bus
        .DINP(8'b0)                   // 8-bit input: FIFO parity input bus - not used
    );

endmodule
