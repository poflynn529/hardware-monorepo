module xilinx_bram_tb;
    // Parameters
    localparam ADDR_WIDTH = 10;
    localparam DATA_WIDTH = 16;  // Changed to 16 to match RAMB18E5
    
    // Testbench signals
    logic                    clk;
    logic                    rst_n;
    logic                    write_en;
    logic                    read_en;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   write_data;
    logic [DATA_WIDTH-1:0]   read_data;
    logic                    valid;
    
    // Instantiate the Xilinx BRAM module
    xilinx_bram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .valid(valid)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period clock
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        write_en = 0;
        read_en = 0;
        addr = 0;
        write_data = 0;
        
        // Display header
        $display("Xilinx BRAM Test Starting");
        $display("------------------------");
        
        // Apply reset
        #20 rst_n = 1;
        
        // Write some data to memory
        $display("\nWriting data to BRAM:");
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            write_en = 1;
            addr = i;
            write_data = 16'hA000 + i;  // Adjusted for 16-bit width
            $display("  Write: Addr = 0x%h, Data = 0x%h", addr, write_data);
            @(posedge clk);
            write_en = 0;
        end
        
        // Read back the data
        $display("\nReading data from BRAM:");
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            read_en = 1;
            addr = i;
            @(posedge clk);
            read_en = 0;
            @(posedge clk); // Wait for data to be valid
            $display("  Read: Addr = 0x%h, Data = 0x%h, Valid = %b", addr, read_data, valid);
        end
        
        // Test read and write to same address
        $display("\nTesting read-after-write:");
        @(posedge clk);
        write_en = 1;
        addr = 10'h3A;
        write_data = 16'h1234;  // Adjusted for 16-bit width
        $display("  Write: Addr = 0x%h, Data = 0x%h", addr, write_data);
        @(posedge clk);
        write_en = 0;
        read_en = 1;
        $display("  Read: Addr = 0x%h", addr);
        @(posedge clk);
        read_en = 0;
        @(posedge clk);
        $display("  Result: Data = 0x%h, Valid = %b", read_data, valid);
        
        // End simulation
        #20;
        $display("\nXilinx BRAM Test Complete");
        $finish;
    end
    
endmodule 