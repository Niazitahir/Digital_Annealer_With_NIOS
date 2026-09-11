`timescale 1ns / 1ps

module tb_tournament_tree_4;

    parameter WIDTH = 5;

    // --- 1. Inputs for the 4-way Tree ---
    reg [WIDTH-1:0] idx0, idx1, idx2, idx3;
    reg v0, v1, v2, v3;
    reg [2:0] rand_bits; // 3 bits for 3 selectors

    // --- 2. Intermediate Wires (Layer 1) ---
    wire [WIDTH-1:0] L1_idx_A, L1_idx_B;
    wire L1_v_A, L1_v_B;

    // --- 3. Final Outputs (Layer 2) ---
    wire [WIDTH-1:0] final_idx;
    wire final_v;

    // --- 4. Instantiate Three Selectors ---
    
    // Layer 1: Left Side (0 vs 1)
    randomized_selector_2to1 #(.WIDTH(WIDTH)) m0 (
        .indexA(idx0), .vA(v0),
        .indexB(idx1), .vB(v1),
        .rand_bit(rand_bits[0]),
        .indexO(L1_idx_A), .vO(L1_v_A)
    );

    // Layer 1: Right Side (2 vs 3)
    randomized_selector_2to1 #(.WIDTH(WIDTH)) m1 (
        .indexA(idx2), .vA(v2),
        .indexB(idx3), .vB(v3),
        .rand_bit(rand_bits[1]),
        .indexO(L1_idx_B), .vO(L1_v_B)
    );

    // Layer 2: Final Arbiter (L1_A vs L1_B)
    randomized_selector_2to1 #(.WIDTH(WIDTH)) m_final (
        .indexA(L1_idx_A), .vA(L1_v_A),
        .indexB(L1_idx_B), .vB(L1_v_B),
        .rand_bit(rand_bits[2]),
        .indexO(final_idx), .vO(final_v)
    );

    // --- 5. Test Stimulus ---
    initial begin
        $display("---------------------------------------------------------");
        $display("     Unit Test: 4-Way Tournament Tree (2 Layers)");
        $display("---------------------------------------------------------");

        // Initialize
        {v0, v1, v2, v3} = 4'b0000;
        {idx0, idx1, idx2, idx3} = {5'd0, 5'd1, 5'd2, 5'd3};
        rand_bits = 3'b000;
        #20;

        // CASE 1: Single Winner (Index 2)
        v0=0; v1=0; v2=1; v3=0;
        #10;
        if (final_idx == 5'd2 && final_v == 1) 
            $display("[PASS] Case 1: Single winner at Index 2 selected.");
        else 
            $display("[FAIL] Case 1: Expected Index 2, Got %d", final_idx);

        // CASE 2: Tie in Layer 1 (0 and 1 both valid)
        // rand_bits[0] = 1 should pick idx0
        v0=1; v1=1; v2=0; v3=0;
        rand_bits[0] = 1; 
        #10;
        if (final_idx == 5'd0) 
            $display("[PASS] Case 2: Layer 1 tie-break (picked 0).");
        else 
            $display("[FAIL] Case 2: Tie-break failed, Got %d", final_idx);

        // CASE 3: Tie in Layer 2 (0 and 3 both valid)
        // L1_A will be 0, L1_B will be 3.
        // rand_bits[2] = 0 should pick the Right side (Index 3).
        v0=1; v1=0; v2=0; v3=1;
        rand_bits[2] = 0; 
        #10;
        if (final_idx == 5'd3) 
            $display("[PASS] Case 3: Layer 2 tie-break (picked 3).");
        else 
            $display("[FAIL] Case 3: Final arbiter failed, Got %d", final_idx);

        // CASE 4: Quadruple Tie (All valid)
        // rand_bits = 101: 
        // L1_A picks 0 (rand[0]=1), L1_B picks 3 (rand[1]=1 is B in our module logic? 
        // Wait, let's check: rand?A:B. So 1 picks A, 0 picks B.
        // rand[0]=1 -> 0 wins. rand[1]=1 -> 2 wins. rand[2]=0 -> Right (2) wins.
        v0=1; v1=1; v2=1; v3=1;
        rand_bits = 3'b011; // [2]=0 (Right), [1]=1 (Left/2), [0]=1 (Left/0)
        #10;
        if (final_idx == 5'd2)
            $display("[PASS] Case 4: Quad tie-break (picked 2).");
        else
            $display("[FAIL] Case 4: Quad tie failed, Got %d", final_idx);

        // CASE 5: No Winners
        v0=0; v1=0; v2=0; v3=0;
        #10;
        if (final_v == 0)
            $display("[PASS] Case 5: Correctly reported no winners.");
        else
            $display("[FAIL] Case 5: Valid flag High when no inputs valid.");

        $display("---------------------------------------------------------");
        $finish;
    end

endmodule