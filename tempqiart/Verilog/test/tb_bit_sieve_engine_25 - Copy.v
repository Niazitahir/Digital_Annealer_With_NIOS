`timescale 1ns / 1ps

module tb_bit_sieve_engine_25;

    // =========================================================================
    // 1. Signals & Constants
    // =========================================================================
    // --- Inputs ---
    reg CLOCK_50;
    reg [3:0] KEY;
    reg [9:0] SW;
    
    // Outputs from DUT
    wire busy;
    wire done;

    // --- Outputs ---
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    // Simulation Control
    integer trial_count = 0;
    integer best_trial_count = -1;
    integer first_found_trial = -1;
    integer file_handle_energy;
    integer file_handle_flips;
    
    reg signed [26:0] best_ising_energy;
    reg signed [255:0] best_current_state_X;



    // =========================================================
    // Vertex Cover Graph Parameters (25-Node, 39-Edge Example)
    // =========================================================
    // You will need to calculate and update this for the new 16-city graph
    integer GLOBAL_MVC_SIZE = 142;

    reg [255:0] adj_matrix [0:255];

    initial begin
        $readmemh("../memoy/adj_mat_MVC.mem", adj_matrix);
    end

    // =========================================================================
    // 2. Instantiate the Device Under Test (DUT)
    // =========================================================================
    BitSieve_256 uut (
        .KEY(KEY),
        .SW(SW),
        .CLOCK_50(CLOCK_50),
        .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), 
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5)
    );

    // =========================================================================
    // 3. Clock Generation (100 MHz -> 10ns period)
    // =========================================================================
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50; // 20ns period = 50 MHz
    end

    // =========================================================================
    // 4. Waveform Generation
    // =========================================================================
    initial begin
        // This creates a .vcd file you can open in GTKWave or ModelSim
        $dumpfile("simulation_dump.vcd");
        $dumpvars(0, tb_bit_sieve_engine_25);
    end

    always @(uut.Ising_Energy) begin
      if (uut.Ising_Energy < best_ising_energy) begin
        best_ising_energy = uut.Ising_Energy;
        best_current_state_X = uut.current_state_X;
        best_trial_count = trial_count;
      end
    end

    // =========================================================================
    // 5. Stimulus Sequence
    // =========================================================================
    initial begin
        // --- A. Initialization ---
        best_ising_energy = 27'h3FFFFFF;
        best_current_state_X = 256'b0;

        KEY = 4'b1111; 
        SW  = 10'd0;

        // 2. Hardware Reset Sequence
        #100;
        KEY[0] = 1'b0; // Press Reset
        #100;
        KEY[0] = 1'b1; // Release Reset
        
        // Wait for the debouncer to finish (Requires modifying the debouncer limit for sim!)
        #500;

        // 3. Program the Hyperparameters and Local Fields
        $display("Programming ROMs...");
        SW[0] = 1'b1; // Assert 'program'
        
        // Wait for the FSM to reach S_READY (mapped to LEDR[2])
        wait(LEDR[2] == 1'b1);
        $display("Programming Complete! System Ready.");

        // 4. Start the Annealing Run
        SW[0] = 1'b0; // Turn off program
        #20;
        //$stop;  // Simulation pauses here

        SW[1] = 1'b1; // Assert 'Go'
        //$display("Run Started...");
        
        $display("----------------------------------------------------------------");
        $display("Starting Simulation: 5 Node Vertex Cover Bit Sieve Engine");
        $display("----------------------------------------------------------------");

        file_handle_energy = $fopen("output_log_energy.txt", "w");
        file_handle_flips = $fopen("output_log_flips.txt", "w");

        if (file_handle_energy == 0) begin
            $display("Error: Could not open file.");
            $finish;
        end

        if (file_handle_flips == 0) begin
            $display("Error: Could not open file.");
            $finish;
        end    

        // 5. Monitor until completion
        wait(LEDR[9] == 1'b1); // Wait for the 'done' LED
        $display("Simulation Complete!");
        
        // Let it idle for a moment before finishing
        #100;
        
        $display("----------------------------------------------------------------");
        $display("[%0t ns] Simulation Complete.", $time);
        $display("Final State X: %64b", uut.current_state_X);
        $display("Best Ising Energy: %7d", best_ising_energy);
        $display("Best Trial Count: %0d", best_trial_count);
        
        if (first_found_trial != -1) begin
            $display(">>> GLOBAL MINIMUM FIRST FOUND AT TRIAL: %0d <<<", first_found_trial);
        end
        $display("----------------------------------------------------------------");
        $finish;
    end

    // =========================================================================
    // 6. Logging (Print X on every trial)
    // =========================================================================
    // We monitor the internal FSM state to trigger the print exactly at the 
    // end of the Update phase (State 6 in our simplified FSM).
    // Note: Hierarchical reference 'uut.control_unit.current_state' depends on
    // your internal naming.
    
    always @(posedge CLOCK_50/*clk*/) begin
        // Check if FSM is in S_UPDATE state (Value 6)
        if (uut.control_unit.current_state == 3'd6) begin
            trial_count = trial_count + 1;
            $fdisplay(file_handle_energy, "%7d", uut.Ising_Energy);

            //if (uut.winner_found) begin
                $fdisplay(file_handle_flips, "%7d", uut.uut.winner_index);
                $write("Trial %4d | X: %64h | Index: %3d | E_off: %5d | deltaE: %7d | Ising_Energy: %7d | ", 
                      trial_count, uut.current_state_X, uut.uut.winner_index, uut.current_E_off, uut.uut.delta_E_array[uut.uut.winner_index], uut.Ising_Energy);
                check_vertex_cover_set(uut.current_state_X, trial_count);
            //end
        end
    end

    task check_vertex_cover_set;
        input  [255:0] state;
        input integer current_trial;
        reg     is_valid;
        
        integer set_size;
        integer i, j;

        begin
            is_valid = 1'b1;
            
            for (i = 0; i < 256; i = i + 1) begin
                for (j = i + 1; j < 256; j = j + 1) begin
                    
                    // Check if bit 'j' in row 'i' is 1 (meaning an edge exists)
                    if (adj_matrix[i][j] == 1'b1) begin
                        
                        // Check if both vertices are uncolored (0)
                        if (state[i] == 1'b0 && state[j] == 1'b0) begin
                            is_valid = 1'b0;
                        end
                        
                    end
                end
            end

            if (is_valid) begin
                $write("VALID VC SET");

                // Count the number of vertices in the set
                set_size = 0;
                for (i = 0; i < 256; i = i + 1) begin
                    if (state[i] == 1'b1) begin
                        set_size = set_size + 1;
                    end
                end

                if (set_size <= GLOBAL_MVC_SIZE) begin
                    $display(" | Size: %0d | SOLUTION FOUND!", set_size);

                    // Record the trial number if this is the first time hitting the minimum
                    if (first_found_trial == -1) begin
                        first_found_trial = current_trial;
                    end

                end else begin
                    $display(" | Size: %0d", set_size);
                end

            end else begin
                $display("");
            end

        end

    endtask

endmodule
