`timescale 1ns / 1ps

// Focused regression: compare the unified engine against the legacy
// bitSieve_engine + acceptance_decision_block composition. The legacy LUT
// contribution is forced to zero because that RNG/LUT path is intentionally
// absent from unified_BitSieve_Engine.
module tb_unified_BitSieve_Engine;

    localparam ISING_WIDTH = 27;
    localparam WEIGHT_WIDTH = 16;
    localparam RANDOM_CASES = 2000;

    reg clk;
    reg rst;
    reg h_update_en;
    reg init_load_en;
    reg X_i;
    reg X_j;
    reg signed [WEIGHT_WIDTH-1:0] weight;
    reg signed [ISING_WIDTH-1:0] init_h_value;
    reg signed [ISING_WIDTH-1:0] E_off;

    wire signed [ISING_WIDTH-1:0] legacy_delta_E;
    wire legacy_decision;
    wire signed [ISING_WIDTH-1:0] unified_delta_E;
    wire unified_decision;

    integer case_number;
    integer error_count;
    integer random_value;

    bitSieve_engine #(
        .N(512),
        .INDEX_WIDTH(9),
        .ISING_WIDTH(ISING_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) legacy_engine (
        .clk(clk),
        .rst(rst),
        .h_update_en(h_update_en),
        .init_load_en(init_load_en),
        .X_i(X_i),
        .X_j(X_j),
        .idx_j(9'd0),
        .weight(weight),
        .init_h_value(init_h_value),
        .delta_E(legacy_delta_E)
    );

    acceptance_decision_block #(
        .DATA_WIDTH(ISING_WIDTH),
        .ADDR_WIDTH(10),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .SEED(16'hACE1)
    ) legacy_adb (
        .clk(clk),
        .rst(rst),
        .rng_en(1'b0),
        .seed(32'h00000001),
        .deltaE(legacy_delta_E),
        .E_off(E_off),
        .decision(legacy_decision)
    );

    unified_BitSieve_Engine #(
        .ISING_WIDTH(ISING_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) unified_engine (
        .clk(clk),
        .rst(rst),
        .h_update_en(h_update_en),
        .init_load_en(init_load_en),
        .X_i(X_i),
        .X_j(X_j),
        .weight(weight),
        .init_h_value(init_h_value),
        .E_off(E_off),
        .delta_E(unified_delta_E),
        .decision(unified_decision)
    );

    always #5 clk = ~clk;

    task compare_outputs;
        begin
            if (unified_engine.local_field !== legacy_engine.h_i) begin
                $display(
                    "LOCAL FIELD MISMATCH case=%0d legacy=%0d unified=%0d",
                    case_number,
                    $signed(legacy_engine.h_i),
                    $signed(unified_engine.local_field)
                );
                error_count = error_count + 1;
            end
            if (unified_delta_E !== legacy_delta_E) begin
                $display(
                    "DELTA-E MISMATCH case=%0d legacy=%0d unified=%0d",
                    case_number,
                    $signed(legacy_delta_E),
                    $signed(unified_delta_E)
                );
                error_count = error_count + 1;
            end
            if (unified_engine.calculation_result
                !== legacy_adb.calculation_result) begin
                $display(
                    "ADB RESULT MISMATCH case=%0d legacy=%0d unified=%0d",
                    case_number,
                    $signed(legacy_adb.calculation_result),
                    $signed(unified_engine.calculation_result)
                );
                error_count = error_count + 1;
            end
            if (unified_decision !== legacy_decision) begin
                $display(
                    "DECISION MISMATCH case=%0d legacy=%b unified=%b",
                    case_number,
                    legacy_decision,
                    unified_decision
                );
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        h_update_en = 1'b0;
        init_load_en = 1'b0;
        X_i = 1'b0;
        X_j = 1'b0;
        weight = {WEIGHT_WIDTH{1'b0}};
        init_h_value = {ISING_WIDTH{1'b0}};
        E_off = {ISING_WIDTH{1'b0}};
        case_number = 0;
        error_count = 0;

        // Eliminate the legacy RNG/LUT contribution for this equivalence test.
        force legacy_adb.lut_val = {ISING_WIDTH{1'b0}};

        repeat (2) @(posedge clk);
        #1 compare_outputs;
        @(negedge clk);
        rst = 1'b0;

        // Directed load-priority case: both controls high must load init_h.
        init_h_value = -27'sd1234567;
        weight = -16'sd32768;
        X_i = 1'b1;
        X_j = 1'b0;
        E_off = 27'sd7654321;
        init_load_en = 1'b1;
        h_update_en = 1'b1;
        @(posedge clk);
        #1 compare_outputs;

        // Randomized cycle-accurate comparison, including hold, load, update,
        // load-over-update, signed extremes, and both conditional inversions.
        for (case_number = 1; case_number <= RANDOM_CASES;
             case_number = case_number + 1) begin
            @(negedge clk);
            random_value = $random;
            h_update_en = random_value[0];
            init_load_en = random_value[1] & random_value[5];
            X_i = random_value[2];
            X_j = random_value[3];
            weight = $random;
            init_h_value = $random;
            E_off = $random;

            @(posedge clk);
            #1 compare_outputs;
        end

        if (error_count == 0) begin
            $display(
                "PASS: unified_BitSieve_Engine matched the legacy datapath for %0d randomized cycles with lut_val=0.",
                RANDOM_CASES
            );
        end else begin
            $display("FAIL: %0d equivalence mismatches.", error_count);
            $fatal(1);
        end
        $finish;
    end

endmodule
