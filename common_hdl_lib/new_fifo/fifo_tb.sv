`timescale 1ns/1ps

module fifo_tb #(
    parameter int DATA_WIDTH = 64,
    parameter int DEPTH = 8
);
    logic clk = 0;
    logic rst = 0;
    logic wr_valid = 0;
    logic [DATA_WIDTH-1:0] wr_data = '0;
    logic wr_ready;
    logic rd_valid;
    logic [DATA_WIDTH-1:0] rd_data;
    logic rd_ready = 0;
    logic [$clog2(DEPTH+1)-1:0] count;
    logic almost_full;

    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (.*);
    always #5 clk = ~clk;

    typedef logic [DATA_WIDTH-1:0] word_t;
    word_t expected[$];
    word_t pending_data;
    bit pending = 0;
    bit accepted_write = 0;
    int errors = 0;
    int cycles = 0;
    int writes = 0;
    int reads = 0;
    int unsigned rng = 32'h12345678;
    int unsigned seed = 32'h12345678;
    string testcase;
    string fst_path;

    initial begin
        if (!$value$plusargs("fst=%s", fst_path)) fst_path = "fifo.fst";
        $dumpfile(fst_path);
        $dumpvars(0, fifo_tb);
    end

    // Contract: DEPTH usable entries, synchronous active-high reset,
    // no empty bypass, and almost_full at occupancy >= DEPTH - 2.
    function automatic int unsigned random32();
        rng ^= rng << 13;
        rng ^= rng >> 17;
        rng ^= rng << 5;
        return rng;
    endfunction

    function automatic word_t random_word();
        word_t value;
        for (int i = 0; i < DATA_WIDTH; i++)
            value[i] = 1'(random32());
        return value;
    endfunction

    task automatic check(input bit condition, input string description);
        if (!condition) begin
            errors++;
            if (errors <= 20)
                $display("%t FAIL [%s] cycle %0d: %s", $time, testcase, cycles, description);
        end
    endtask

    task automatic step(input bit reset_i, input bit write_i,
                        input bit read_i, input word_t data_i);
        bit take_write;
        bit take_read;
        // Enter after the previous rising edge has settled; drive the next cycle.
        rst = reset_i;
        wr_valid = write_i;
        rd_ready = read_i;
        wr_data = data_i;
        #1;
        if (!reset_i) begin
            check(int'(count) == expected.size(), "occupancy check");
            check(rd_valid == (expected.size() != 0), "read availability check");
            // Full may optionally accept a write when a read frees a slot.
            if (expected.size() < DEPTH)
                check(wr_ready, "write availability check");
            else if (!read_i)
                check(!wr_ready, "full backpressure check");
            check(almost_full == (expected.size() == DEPTH - 1),
                  "almost_full contract check");
            if (expected.size() != 0)
                check(rd_data === expected[0], "front data/order/stability check");
        end
        take_write = write_i && wr_ready;
        take_read = read_i && rd_valid;
        accepted_write = !reset_i && take_write;
        @(posedge clk);
        if (reset_i) begin
            expected.delete();
        end else begin
            if (take_read) begin
                check(expected.size() != 0, "read underflow check");
                if (expected.size() != 0) void'(expected.pop_front());
                reads++;
            end
            if (take_write) begin
                check(expected.size() < DEPTH, "write overflow check");
                expected.push_back(data_i);
                writes++;
            end
        end
        #1;
        check(int'(count) == expected.size(), "post-clock occupancy check");
        check(rd_valid == (expected.size() != 0), "post-clock read availability check");
        if (expected.size() != 0)
            check(rd_data === expected[0], $sformatf("post-clock data check. Expected: %h, Actual: %h", expected[0], rd_data));
        cycles++;
    endtask

    task automatic start_case(input string name);
        testcase = name;
        $display("TEST %s", name);
        step(1, 0, 0, '0);
        step(0, 0, 0, '0);
    endtask

    initial begin
        if ($value$plusargs("seed=%d", seed)) begin end
        if (seed == 0) seed = 1;
        rng = seed;
        $display("FIFO test: width=%0d depth=%0d seed=%0d", DATA_WIDTH, DEPTH, seed);

        @(posedge clk);
        #1;

        start_case("empty reads and idle");
        repeat (12) step(0, 0, 1, '0);

        start_case("single words and bit patterns");
        for (int i = 0; i < DATA_WIDTH + 2; i++) begin
            step(0, 1, 0, i == DATA_WIDTH ? '1 : (word_t'(1) << i));
            repeat (4) step(0, 0, 0, random_word());
            step(0, 0, 1, '0);
        end

        start_case("fill, blocked writes, stalled reads, drain");
        for (int i = 0; i < DEPTH; i++) step(0, 1, 0, word_t'(i));
        repeat (8) step(0, 1, 0, '1);
        repeat (8) step(0, 0, 0, '0);
        repeat (DEPTH + 4) step(0, 0, 1, '0);

        start_case("simultaneous transfers from empty");
        repeat (DEPTH * 5) step(0, 1, 1, random_word());
        repeat (DEPTH + 2) step(0, 0, 1, '0);

        start_case("simultaneous transfers from full");
        repeat (DEPTH) step(0, 1, 0, random_word());
        repeat (DEPTH * 5) step(0, 1, 1, random_word());
        repeat (DEPTH + 2) step(0, 0, 1, '0);

        start_case("repeated pointer wraparound");
        repeat (12) begin
            repeat (DEPTH) step(0, 1, 0, random_word());
            repeat (DEPTH) step(0, 0, 1, '0);
        end

        start_case("reset while occupied and active");
        repeat (DEPTH / 2 + 1) step(0, 1, 0, random_word());
        repeat (3) step(1, 1, 1, '1);
        repeat (4) step(0, 0, 1, '0);
        repeat (DEPTH) step(0, 1, 0, random_word());
        step(1, 1, 0, '1);
        step(0, 0, 1, '0);

        start_case("random traffic with held producer and resets");
        for (int i = 0; i < 4000; i++) begin
            bit reset_i;
            bit read_i;
            reset_i = (random32() % 137 == 0);
            read_i = (random32() % 100 < (i % 300 < 150 ? 20 : 80));
            if (!pending && random32() % 100 < 70) begin
                pending = 1;
                pending_data = random_word();
            end
            step(reset_i, pending, read_i, pending_data);
            if (reset_i || accepted_write) pending = 0;
        end
        repeat (DEPTH + 2) step(0, 0, 1, '0);
        check(expected.size() == 0, "final drain check");
        $display("RESULT width=%0d depth=%0d cycles=%0d writes=%0d reads=%0d errors=%0d",
                 DATA_WIDTH, DEPTH, cycles, writes, reads, errors);
        $dumpflush;
        if (errors != 0) $fatal(1, "FIFO test failed");
        $display("PASS");
        $finish;
    end

    initial begin
        #10000000;
        $dumpflush;
        $fatal(1, "Testbench timeout");
    end
endmodule
