module xilinx_bram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 16
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    write_en,
    input  logic                    read_en,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   write_data,
    output logic [DATA_WIDTH-1:0]   read_data,
    output logic                    valid
);

    // Valid signal logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
        end else begin
            valid <= read_en;
        end
    end

    // Instantiate Xilinx BRAM primitive
    // Using RAMB18E5 (18K Block RAM)
    RAMB18E5 #(
        // Configure as a single port RAM
        .DOA_REG(0),                // Output register disabled
        .DOB_REG(0),                // Output register disabled
        .READ_WIDTH_A(DATA_WIDTH),  // Read width for port A
        .READ_WIDTH_B(0),           // Port B not used for reading
        .WRITE_WIDTH_A(DATA_WIDTH), // Write width for port A
        .WRITE_WIDTH_B(0),          // Port B not used for writing
        .SIM_COLLISION_CHECK("ALL") // Collision checking
    ) bram_inst (
        // Port A (used for both read and write)
        .CLKARDCLK(clk),                // Clock for read port
        .CLKBWRCLK(1'b0),               // Clock for write port B (unused)
        .ENARDEN(read_en || write_en),  // Enable for read port
        .ENBWREN(1'b0),                 // Enable for write port B (unused)
        .RSTRAMARSTRAM(!rst_n),         // Reset (active high for BRAM)
        .RSTRAMB(1'b0),                 // Reset for port B (unused)
        .RSTREGARSTREG(1'b0),           // Output register reset (unused)
        .RSTREGB(1'b0),                 // Output register reset for port B (unused)
        
        // Address ports - fixed to use 11 bits as required
        .ADDRARDADDR({1'b0, addr}),     // Address for port A (read/write) - 11 bits
        .ADDRBWRADDR(11'b0),            // Address for port B (unused) - 11 bits
        
        // Data ports
        .DINADIN(write_data),           // Input data for port A
        .DINBDIN(16'b0),                // Input data for port B (unused)
        .DOUTADOUT(read_data),          // Output data from port A
        .DOUTBDOUT(),                   // Output data from port B (unused)
        
        // Parity ports (unused)
        .DINPADINP(2'b0),               // Input parity for port A
        .DINPBDINP(2'b0),               // Input parity for port B
        .DOUTPADOUTP(),                 // Output parity from port A
        .DOUTPBDOUTP(),                 // Output parity from port B
        
        // Write enable
        .WEA({2{write_en}}),            // Write enable for port A
        .WEBWE(4'b0),                   // Write enable for port B (unused)
        
        // Sleep mode (unused)
        .SLEEP(1'b0),
        
        // Asynchronous reset ports
        .ARST_A(!rst_n),                // Asynchronous reset for port A
        .ARST_B(1'b0),                  // Asynchronous reset for port B (unused)
        
        // Cascade ports (unused)
        .CASDINA(16'b0),
        .CASDINB(16'b0),
        .CASDINPA(2'b0),
        .CASDINPB(2'b0),
        .CASDOMUXA(1'b0),
        .CASDOMUXB(1'b0),
        .CASDOMUXEN_A(1'b0),
        .CASDOMUXEN_B(1'b0),
        .CASDOUTA(),
        .CASDOUTB(),
        .CASDOUTPA(),
        .CASDOUTPB(),
        
        // Register control (unused)
        .REGCEAREGCE(1'b0),
        .REGCEB(1'b0),
        
        // Output register cascade mux control
        .CASOREGIMUXA(1'b0),            // Cascade output register mux A
        .CASOREGIMUXB(1'b0),            // Cascade output register mux B
        .CASOREGIMUXEN_A(1'b0),         // Cascade output register mux enable A
        .CASOREGIMUXEN_B(1'b0)          // Cascade output register mux enable B
    );

endmodule 