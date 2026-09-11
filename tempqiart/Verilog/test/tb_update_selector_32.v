`timescale 1ns / 1ps

module tb_update_selector_32;

    // --- 1. DUT Signals ---
    reg  [159:0] idx_in_flat;
    reg  [31:0]  val_in_flat;
    reg  [30:0]  rand_bits;
    
    wire [4:0]   final_index;
    wire         final_valid;

    // --- 2. Testbench Variables ---
    reg [4:0] expected_index;
    reg       expected_valid;
    integer   pass_count = 0;
    integer   fail_count = 0;
    integer   i;

    // --- 3. Instantiate the DUT ---
    update_selector_32 uut (
        .idx_in_flat(idx_in_flat),
        .val_in_flat(val_in_flat),
        .rand_bits(rand_bits),
        .final_index(final_index),
        .final_valid(final_valid)
    );

    // --- 4. The "Golden Model" (Software implementation of the tree) ---
    // This calculates the expected outcome so we can test random distributions easily.
    task calculate_expected;
        input  [31:0] vals;
        input  [30:0] rands;
        output [4:0]  exp_idx;
        output        exp_v;
        
        reg [4:0] l1_idx [0:15]; reg l1_v [0:15];
        reg [4:0] l2_idx [0:7];  reg l2_v [0:7];
        reg [4:0] l3_idx [0:3];  reg l3_v [0:3];
        reg [4:0] l4_idx [0:1];  reg l4_v [0:1];
        integer k;
        begin
            // Layer 1 (uses rands[15:0])
            for (k=0; k<16; k=k+1) begin
                l1_v[k] = vals[2*k] | vals[2*k+1];
                if (vals[2*k] && vals[2*k+1]) l1_idx[k] = rands[k] ? (2*k) : (2*k+1);
                else if (vals[2*k])           l1_idx[k] = 2*k;
                else if (vals[2*k+1])         l1_idx[k] = 2*k+1;
                else                          l1_idx[k] = 0;
            end
            // Layer 2 (uses rands[23:16])
            for (k=0; k<8; k=k+1) begin
                l2_v[k] = l1_v[2*k] | l1_v[2*k+1];
                if (l1_v[2*k] && l1_v[2*k+1]) l2_idx[k] = rands[16+k] ? l1_idx[2*k] : l1_idx[2*k+1];
                else if (l1_v[2*k])           l2_idx[k] = l1_idx[2*k];
                else if (l1_v[2*k+1])         l2_idx[k] = l1_idx[2*k+1];
                else                          l2_idx[k] = 0;
            end
            // Layer 3 (uses rands[27:24])
            for (k=0; k<4; k=k+1) begin
                l3_v[k] = l2_v[2*k] | l2_v[2*k+1];
                if (l2_v[2*k] && l2_v[2*k+1]) l3_idx[k] = rands[24+k] ? l2_idx[2*k] : l2_idx[2*k+1];
                else if (l2_v[2*k])           l3_idx[k] = l2_idx[2*k];
                else if (l2_v[2*k+1])         l3_idx[k] = l2_idx[2*k+1];
                else                          l3_idx[k] = 0;
            end
            // Layer 4 (uses rands[29:28])
            for (k=0; k<2; k=k+1) begin
                l4_v[k] = l3_v[2*k] | l3_v[2*k+1];
                if (l3_v[2*k] && l3_v[2*k+1]) l4_idx[k] = rands[28+k] ? l3_idx[2*k] : l3_idx[2*k+1];
                else if (l3_v[2*k])           l4_idx[k] = l3_idx[2*k];
                else if (l3_v[2*k+1])         l4_idx[k] = l3_idx[2*k+1];
                else                          l4_idx[k] = 0;
            end
            // Layer 5 (uses rands[30])
            exp_v = l4_v[0] | l4_v[1];
            if (l4_v[0] && l4_v[1]) exp_idx = rands[30] ? l4_idx[0] : l4_idx[1];
            else if (l4_v[0])       exp_idx = l4_idx[0];
            else if (l4_v[1])       exp_idx = l4_idx[1];
            else                    exp_idx = 0;
        end
    endtask

    // --- 5. Main Test Sequence ---
    initial begin
        $display("=========================================================");
        $display("     Full System Test: 32-Input Tournament Selector");
        $display("=========================================================");
        
        // Setup: Pack the static indices (0 to 31) into the flattened array
        for (i = 0; i < 32; i = i + 1) begin
            idx_in_flat[i*5 +: 5] = i[4:0];
        end

        // Wait for global reset
        #100;

        // -------------------------------------------------------------
        // CASE 1: No Valid Inputs (The "Idle" state)
        // -------------------------------------------------------------
        val_in_flat = 32'h0000_0000;
        rand_bits   = 31'h7FFF_FFFF; // Doesn't matter, but set it
        #10;
        calculate_expected(val_in_flat, rand_bits, expected_index, expected_valid);
        check_result(1);

        // -------------------------------------------------------------
        // CASE 2: All Valid Inputs (The "Maximum Collision" state)
        // -------------------------------------------------------------
        val_in_flat = 32'hFFFF_FFFF;
        // Let's use an alternating pattern for rand_bits: 10101...
        rand_bits   = 31'h5555_5555; 
        #10;
        calculate_expected(val_in_flat, rand_bits, expected_index, expected_valid);
        check_result(2);
        
        // Another "All Valid" test with different rands
        rand_bits   = 31'h0000_0000; // Force it to always pick the Right side
        #10;
        calculate_expected(val_in_flat, rand_bits, expected_index, expected_valid);
        check_result(3);

        // -------------------------------------------------------------
        // CASE 4-8: Random Sparse Distributions
        // -------------------------------------------------------------
        for (i = 4; i <= 8; i = i + 1) begin
            // Generate random 32-bit validation array and 31-bit random tree decisions
            val_in_flat = {$random, $random}; 
            rand_bits   = {$random, $random} & 31'h7FFFFFFF;
            #10;
            
            calculate_expected(val_in_flat, rand_bits, expected_index, expected_valid);
            check_result(i);
        end

        $display("=========================================================");
        $display("Test Complete: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("=========================================================");
        $finish;
    end

    // --- 6. Helper Task for Checking and Printing ---
    task check_result;
        input integer test_num; // Replaced string with simple integer
        begin
            if ((final_index !== expected_index) || (final_valid !== expected_valid)) begin
                $display("[FAIL] Case %0d", test_num);
                $display("       Expected: Valid=%b, Index=%0d", expected_valid, expected_index);
                $display("       Got:      Valid=%b, Index=%0d", final_valid, final_index);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] Case %0d -> Winner: %0d (Valid: %b)", test_num, final_index, final_valid);
                pass_count = pass_count + 1;
            end
        end
    endtask

endmodule