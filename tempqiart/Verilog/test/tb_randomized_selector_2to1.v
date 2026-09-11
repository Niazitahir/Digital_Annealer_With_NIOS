`timescale 1ns / 1ps

module tb_randomized_selector_2to1;

    // --- 1. DUT Parameters & Signals ---
    parameter WIDTH = 5;
    
    reg [WIDTH-1:0] indexA, indexB;
    reg vA, vB;
    reg rand_bit;
    
    wire [WIDTH-1:0] indexO;
    wire vO;
    
    // --- 2. Expected Output Variables ---
    reg [WIDTH-1:0] exp_indexO;
    reg exp_vO;
    
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    // --- 3. Instantiate the Device Under Test (DUT) ---
    randomized_selector_2to1 #( .WIDTH(WIDTH) ) uut (
        .indexA(indexA), .vA(vA),
        .indexB(indexB), .vB(vB),
        .rand_bit(rand_bit),
        .indexO(indexO),
        .vO(vO)
    );

    // --- 4. Test Logic ---
    initial begin
        $display("---------------------------------------------------------");
        $display("     Unit Test: Randomized Selector 2-to-1");
        $display("---------------------------------------------------------");
        
        // Wait 100ns for global reset/startup
        #100;
        
        // Run 20 Random Test Cases
        for (i = 1; i <= 20; i = i + 1) begin
            
            // A. Generate Random Inputs
            indexA   = $random % 32; // 5-bit random (0-31)
            indexB   = $random % 32;
            vA       = $random % 2;  // 1-bit random
            vB       = $random % 2;
            rand_bit = $random % 2;
            
            // B. Wait for Combinational Logic to Settle
            #10;
            
            // C. Calculate Expected Output (The Golden Model)
            exp_vO = vA | vB;
            
            if (vA && vB) begin
                // Tie-breaker case: Use rand_bit
                exp_indexO = (rand_bit) ? indexA : indexB;
            end else if (vA) begin
                // Only A is valid
                exp_indexO = indexA;
            end else if (vB) begin
                // Only B is valid
                exp_indexO = indexB;
            end else begin
                // Neither valid
                exp_indexO = {WIDTH{1'b0}};
            end
            
            // D. Compare and Report
            if ((indexO !== exp_indexO) || (vO !== exp_vO)) begin
                $display("[FAIL] Case %2d: vA=%b vB=%b rand=%b | A=%d B=%d", 
                         i, vA, vB, rand_bit, indexA, indexB);
                $display("       Expected: Valid=%b Index=%d", exp_vO, exp_indexO);
                $display("       Got:      Valid=%b Index=%d", vO, indexO);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] Case %2d: vA=%b vB=%b rand=%b | A=%d B=%d", 
                         i, vA, vB, rand_bit, indexA, indexB);
                $display("       Expected: Valid=%b Index=%d", exp_vO, exp_indexO);
                $display("       Got:      Valid=%b Index=%d", vO, indexO);
                pass_count = pass_count + 1;
            end
            $display("---------------------------------------------------------");
        end
        
        $display("---------------------------------------------------------");
        $display("Test Complete: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("---------------------------------------------------------");
        $finish;
    end

endmodule