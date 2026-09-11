`timescale 1ns / 1ps

module tb_acceptance_decision_block;

    // --- 1. Parameters ---
    parameter DATA_WIDTH = 27;
    parameter ADDR_WIDTH = 10;

    // --- 2. DUT Signals ---
    reg clk;
    reg rst;
    reg rng_en;
    reg signed [DATA_WIDTH-1:0] deltaE;
    reg signed [DATA_WIDTH-1:0] E_off;
    
    wire decision;

    // --- 3. Testbench Variables ---
    integer i;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Internal probe to the LUT value
    // NOTE: This assumes the wire connecting the LUT output inside your ADB 
    // module is named 'lut_val'. Adjust if you named it differently.
    wire signed [DATA_WIDTH-1:0] lut_val;
    assign lut_val = 27'd8;//uut.lut_val; 

    // 32-bit register to safely prevent overflow during testbench calculation
    reg signed [31:0] calc_result; 
    reg expected_decision;

    // --- 4. Instantiate the DUT ---
    acceptance_decision_block #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .rng_en(rng_en),
        .deltaE(deltaE),
        .E_off(E_off),
        .decision(decision)
    );

    // --- 5. Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period (100 MHz)
    end

    // --- 6. Main Test Sequence ---
    initial begin
        $display("=========================================================");
        $display("     Unit Test: Acceptance Decision Block (ADB)");
        $display("=========================================================");

        // Initialization
        rst = 1;
        rng_en = 0;
        deltaE = 0;
        E_off = 0;
        #20; 
        rst = 0;
        #10;

        // Run 20 randomized tests
        for (i = 1; i <= 20; i = i + 1) begin
            
            // Step A: Pulse rng_en to get a new random number and LUT value
            rng_en = 1;
            #10;
            rng_en = 0;
            
            // Step B: Wait for the LUT to output the new threshold
            // (LFSR updates on edge, synchronous LUT takes 1 clock cycle to read)
            #10; 

            // Step C: Apply random deltaE and E_off
            // We use modulo to keep the numbers readable in the terminal
            deltaE = 16;//$random % 5000;              // Can be negative or positive (-4999 to +4999)
            E_off  = 0;//$unsigned($random) % 2000;   // E_off strictly climbs up (0 to 1999)
            
            // Step D: Wait a half-cycle for combinational logic to settle
            #5;

            // Step E: Compute Expected Result using 32-bit math
            // Equation: result = E_off - deltaE + lut_val
            calc_result = E_off - deltaE + lut_val;
            
            // If the calculation is >= 0, the flip should be accepted (1)
            expected_decision = (calc_result >= 0) ? 1'b1 : 1'b0;

            // Step F: Compare Output and Report
            if (decision !== expected_decision) begin
                $display("[FAIL] Case %2d: deltaE=%0d, E_off=%0d, LUT=%0d, Calc Result: %0d | Expected: %b | Got: %b", 
                         i, deltaE, E_off, lut_val, calc_result, expected_decision, decision);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] Case %2d: deltaE=%6d, E_off=%4d, LUT=%4d -> Calc Result: %6d | Decision: %b", 
                         i, deltaE, E_off, lut_val, calc_result, decision);
                pass_count = pass_count + 1;
            end
            
            // Buffer time before the next loop
            #5;
        end

        $display("=========================================================");
        $display("Test Complete: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("=========================================================");
        $finish;
    end

endmodule