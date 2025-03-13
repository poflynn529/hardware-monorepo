module counter_tb;
    // Testbench signals
    logic        clk;
    logic        rst_n;
    logic        enable;
    logic [7:0]  count;
    
    // Instantiate the DUT
    counter dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .count(count)
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
        enable = 0;
        
        // Display header
        $display("Time\tReset\tEnable\tCount");
        $display("----\t-----\t------\t-----");
        
        // Apply reset
        #20 rst_n = 1;
        
        // Enable counter and observe for a few cycles
        #10 enable = 1;
        
        // Run for some time and display values
        repeat(20) begin
            @(posedge clk);
            #1; // Small delay for signal stability
            $display("%0t\t%b\t%b\t%h", $time, rst_n, enable, count);
        end
        
        // Disable counter
        enable = 0;
        #20;
        
        // End simulation
        $display("Simulation complete");
        $finish;
    end
    
endmodule 