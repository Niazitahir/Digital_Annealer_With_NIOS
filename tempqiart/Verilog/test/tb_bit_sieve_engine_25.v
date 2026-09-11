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
    integer file_handle_best;
    integer max_iter_override;
    integer constant_raw_for_log;
    integer constant_for_log;
    integer global_min_raw_for_log;
    
    reg signed [27:0] best_ising_energy;
    reg signed [27:0] best_ising_energy_raw;
    reg [1023:0] best_current_state_X;
    reg run_started;



    // =========================================================
    // UAV Replacement QUBO Parameters
    // =========================================================
    // These values are loaded from hyperparameter ROM words 05 and 06 after
    // programming. Plusargs remain available for isolated testbench runs.
    integer CONSTANT_RAW_Q25_2 = 0;
    integer GLOBAL_MIN_RAW_Q25_2 = 0;

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
        // Batch mode supplies +NO_VCD because a full dump is hundreds of MB.
        // Manual runs retain the existing waveform-dump behaviour.
        if (!$test$plusargs("NO_VCD")) begin
            $dumpfile("simulation_dump.vcd");
            $dumpvars(0, tb_bit_sieve_engine_25);
        end
    end

    // S_UPDATE commits state and energy with nonblocking assignments. On the
    // following falling edge, S_WEIGHT_WAIT is active and both values are
    // aligned and stable. Compare raw Q25.2 values so quarter-unit gains are
    // not lost through integer division.
    always @(negedge CLOCK_50) begin
        if (run_started &&
            (uut.control_unit.current_state == 4'd11) &&
            ($signed(uut.Ising_Energy) < $signed(best_ising_energy_raw))) begin
            best_ising_energy_raw = $signed(uut.Ising_Energy);
            best_ising_energy = $signed(uut.Ising_Energy) / 4;
            best_current_state_X = uut.current_state_X;
            best_trial_count = trial_count;
        end
    end

    // =========================================================================
    // 5. Stimulus Sequence
    // =========================================================================
    initial begin
        // --- A. Initialization ---
        best_ising_energy = 28'h7FFFFFF;
        best_ising_energy_raw = 28'h7FFFFFF;
        best_current_state_X = 1024'b0;
        run_started = 1'b0;
        constant_for_log = 0;
        constant_raw_for_log = CONSTANT_RAW_Q25_2;
        global_min_raw_for_log = GLOBAL_MIN_RAW_Q25_2;

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

        // The Python generator writes these model-specific quantities into
        // ROM addresses 05 and 06. The wrapper captures them during S_PROGRAM.
        constant_raw_for_log = $signed(uut.qubo_constant_raw_reg);
        constant_for_log = constant_raw_for_log / 4;
        global_min_raw_for_log = $signed(uut.global_min_raw_reg);

        $display(
            "Loaded configuration: max_iter=%0d, tabu_depth=%0d, active_variables=%0d, E_off_step_raw=%0d, selector_seed=0x%08h.",
            uut.max_iter_reg,
            uut.penalty_reg[9:0],
            uut.active_variable_count_reg,
            $signed(uut.e_off_delta_reg),
            uut.random_seed_reg
        );

        // Optional command-line smoke-test override. Normal GUI and batch
        // runs continue to use the max-iteration value loaded from the MIF.
        if ($value$plusargs("MAX_ITER=%d", max_iter_override)) begin
            uut.max_iter_reg = max_iter_override;
            $display("Overriding max iterations with %0d.", max_iter_override);
        end
        if ($value$plusargs("QUBO_CONSTANT_RAW=%d", constant_raw_for_log)) begin
            $display(
                "Using Q25.2 QUBO constant %0d for result logging.",
                constant_raw_for_log
            );
        end
        if ($value$plusargs("QUBO_CONSTANT=%d", constant_for_log)) begin
            $display("Using displayed QUBO constant %0d.", constant_for_log);
        end
        if ($value$plusargs("GLOBAL_MIN_RAW=%d", global_min_raw_for_log)) begin
            $display(
                "Using global minimum %0d in raw Q25.2 units.",
                global_min_raw_for_log
            );
        end

        // 4. Start the Annealing Run
        SW[0] = 1'b0; // Turn off program
        #20;
        //$stop;  // Simulation pauses here

        $display("----------------------------------------------------------------");
        $display("Starting Simulation: UAV Replacement Bit Sieve Engine");
        $display("----------------------------------------------------------------");

        // The detailed trajectory logs are useful for an interactive/manual
        // run, but writing them for every member of a 110-run batch adds I/O
        // and leaves files that the aggregate CSV makes unnecessary.
        file_handle_energy = 0;
        file_handle_flips = 0;
        if (!$test$plusargs("QUIET_BATCH")) begin
            file_handle_energy = $fopen("output_log_energy.txt", "w");
            file_handle_flips = $fopen("output_log_flips.txt", "w");
        end
        file_handle_best = $fopen("best_run_result.txt", "w");

        if ((file_handle_best == 0) ||
            (!$test$plusargs("QUIET_BATCH") &&
             ((file_handle_energy == 0) || (file_handle_flips == 0)))) begin
            $display("Error: Could not open one or more simulation log files.");
            $finish;
        end

        // Treat the loaded initial state as trial zero. This guarantees that
        // every run has a valid best record even when no move improves it.
        best_ising_energy_raw = $signed(uut.Ising_Energy);
        best_ising_energy = $signed(uut.Ising_Energy) / 4;
        best_current_state_X = uut.current_state_X;
        best_trial_count = 0;
        trial_count = 0;
        run_started = 1'b1;

        SW[1] = 1'b1; // Assert 'Go'
        //$display("Run Started...");

        // 5. Monitor until completion
        wait(LEDR[9] == 1'b1); // Wait for the 'done' LED
        $display("Simulation Complete!");
        
        // Let it idle for a moment before finishing
        #100;

        $display("----------------------------------------------------------------");
        $display("[%0t ns] Simulation Complete.", $time);
        $display("Final State X: %256h", uut.current_state_X);
        $display("Best Ising Energy: %7d", best_ising_energy);
        $display("Best Ising Energy Raw Q25.2: %7d", best_ising_energy_raw);
        $display("Best Trial Count: %0d", best_trial_count);
        
        if (first_found_trial != -1) begin
            $display(">>> GLOBAL MINIMUM FIRST FOUND AT TRIAL: %0d <<<", first_found_trial);
        end
        $display("----------------------------------------------------------------");

        // One machine-readable record for the Python batch runner. Energies
        // remain in raw Q25.2 units so no fractional precision is discarded.
        $fdisplay(
            file_handle_best,
            "{\"trial\":%0d,\"state\":\"%0256h\",\"ising_energy_raw_q25_2\":%0d,\"hovering_energy_raw_q25_2\":%0d}",
            best_trial_count,
            best_current_state_X,
            $signed(best_ising_energy_raw),
            constant_raw_for_log + $signed(best_ising_energy_raw)
        );
        $fclose(file_handle_best);
        if (file_handle_energy != 0) begin
            $fclose(file_handle_energy);
        end
        if (file_handle_flips != 0) begin
            $fclose(file_handle_flips);
        end
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
        if (uut.control_unit.current_state == 4'd6) begin
            trial_count = trial_count + 1;
            if ($test$plusargs("QUIET_BATCH") &&
                ((trial_count == 1) || ((trial_count % 10) == 0))) begin
                $display("BATCH_PROGRESS trial=%0d", trial_count);
            end
            if (file_handle_energy != 0) begin
                $fdisplay(file_handle_energy, "%7d", uut.Ising_Energy/4);
            end

            //if (uut.winner_found) begin
                if (file_handle_flips != 0) begin
                    $fdisplay(file_handle_flips, "%7d", uut.uut.winner_index);
                end
                if (!$test$plusargs("QUIET_BATCH")) begin
                    $write("Trial %4d | X: %256h | \nIndex: %4d | E_off: %5d | deltaE: %7d | Ising_Energy: %7d | Hovering Energy: %3d", 
                          trial_count, uut.current_state_X, uut.uut.winner_index, uut.current_E_off, uut.uut.delta_E_array[uut.uut.winner_index], uut.Ising_Energy/4, constant_for_log + uut.Ising_Energy/4);
                end
                if ((global_min_raw_for_log != 0) &&
                    (constant_raw_for_log + $signed(uut.Ising_Energy)
                     <= global_min_raw_for_log) &&
                    (first_found_trial == -1)) begin
                    $display(" >>> GLOBAL MINIMUM FOUND! <<<");
                    first_found_trial = trial_count;
                end
                if (!$test$plusargs("QUIET_BATCH")) begin
                    $display("");
                end
            //end
        end
    end

endmodule
