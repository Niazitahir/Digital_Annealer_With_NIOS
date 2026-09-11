// 2048-logical-engine Bit-Sieve datapath.
//
// The hierarchy contains 1024 twin engines. Twin i owns logical engines i and
// i+1024 and performs the first 2-to-1 tournament decision locally. The 1024
// pair-valid results then use the existing ten-level matrix selector.
module bit_sieve_engine_25 #(
    parameter integer N = 2048,
    parameter integer INDEX_WIDTH = 11,
    parameter integer SELECTOR_WIDTH = 2048,
    parameter integer FIELD_WIDTH = 28,
    parameter integer ENERGY_WIDTH = 32,
    parameter integer WEIGHT_WIDTH = 10
)(
    input wire clk,
    input wire rst,
    input wire signed [FIELD_WIDTH-1:0] h_init_value,
    input wire rng_ADB_en,
    input wire rng_US_en,
    input wire ising_update_en,
    input wire state_update_en,
    input wire valid_hold_en,
    input wire e_off_update_en,
    input wire h_update_en,
    input wire [N-1:0] engine_load_en,
    input wire [(N*WEIGHT_WIDTH)-1:0] packed_weights,
    input wire [INDEX_WIDTH-1:0] tabu_depth,
    input wire [INDEX_WIDTH:0] active_variable_count,
    input wire signed [ENERGY_WIDTH-1:0] init_ising_energy,
    input wire [31:0] random_seed,
    input wire signed [FIELD_WIDTH-1:0] e_off_delta,
    output wire winner_found_out,
    output wire [INDEX_WIDTH-1:0] winner_index_out,
    input wire [N-1:0] starting_state,
    output reg [N-1:0] current_state_X,
    output reg signed [ENERGY_WIDTH-1:0] Ising_Energy,
    output wire signed [FIELD_WIDTH-1:0] current_E_off
);

    localparam integer TWIN_COUNT = N / 2;
    localparam integer MATRIX_INDEX_WIDTH = INDEX_WIDTH - 1;

    wire winner_found;
    wire [MATRIX_INDEX_WIDTH-1:0] matrix_winner_index;
    wire matrix_winner_identifier;
    wire [INDEX_WIDTH-1:0] winner_index;
    wire winner_X_val;

    wire signed [FIELD_WIDTH-1:0] delta_E_array [0:N-1];
    wire [N-1:0] valid_bits;
    wire [N-1:0] tabu_mask;
    reg  [N-1:0] valid_candidates;
    wire [N-1:0] active_engine_mask;
    wire [TWIN_COUNT-1:0] pair_valid_bits;
    wire [TWIN_COUNT-1:0] pair_identifier_bits;
    wire [TWIN_COUNT*FIELD_WIDTH-1:0] pair_delta_e_bits;
    wire signed [FIELD_WIDTH-1:0] final_delta_e;

    wire signed [WEIGHT_WIDTH-1:0] weights [0:N-1];
    wire signed [ENERGY_WIDTH-1:0] winning_delta_E_extended;
    reg [SELECTOR_WIDTH-1:0] tree_rand;

    genvar i;
    integer rng_word;

    assign winner_index = {matrix_winner_identifier, matrix_winner_index};
    assign winner_found_out = winner_found;
    assign winner_index_out = winner_index;
    assign winner_X_val = current_state_X[winner_index];
    assign winning_delta_E_extended = {
        {(ENERGY_WIDTH-FIELD_WIDTH){final_delta_e[FIELD_WIDTH-1]}},
        final_delta_e
    };

    generate
        for (i = 0; i < N; i = i + 1) begin : active_mask_bits
            assign active_engine_mask[i] = (i < active_variable_count);
            assign weights[i] = packed_weights[(i*WEIGHT_WIDTH) +: WEIGHT_WIDTH];
        end
    endgenerate

    e_off_generator #(.WIDTH(FIELD_WIDTH)) u_e_off (
        .clk(clk),
        .rst(rst),
        .delta_val(e_off_delta),
        .en(e_off_update_en),
        .winner_found(winner_found),
        .E_off(current_E_off)
    );

    tabu_mask_generator #(
        .MAX_DEPTH(N),
        .INDEX_WIDTH(INDEX_WIDTH),
        .MASK_WIDTH(N),
        .ZERO_BITS(N)
    ) tabu_buffer (
        .clk(clk),
        .rst(rst),
        .shift_en(state_update_en & winner_found),
        .new_index(winner_index),
        .depth(tabu_depth),
        .tabu_mask_gated(tabu_mask)
    );

    always @(posedge clk) begin
        if (rst) begin
            current_state_X  <= starting_state;
            Ising_Energy     <= {ENERGY_WIDTH{1'b0}};
            valid_candidates <= {N{1'b0}};
        end else begin
            if (state_update_en && winner_found)
                current_state_X <= current_state_X ^
                    ({{(N-1){1'b0}}, 1'b1} << winner_index);

            if (engine_load_en[4])
                Ising_Energy <= init_ising_energy;
            else if (ising_update_en && winner_found)
                Ising_Energy <= Ising_Energy + winning_delta_E_extended;

            if (valid_hold_en)
                valid_candidates <= valid_bits & active_engine_mask & ~tabu_mask;
        end
    end

    // Each hierarchy instance owns logical lane i and lane i+1024. Both lanes
    // receive the same selected-state X_j but retain independent h_i state.
    generate
        for (i = 0; i < TWIN_COUNT; i = i + 1) begin : twin_engine_array
            twin_unified_BitSieve_Engine #(
                .FIELD_WIDTH(FIELD_WIDTH),
                .WEIGHT_WIDTH(WEIGHT_WIDTH)
            ) u_twin_engine (
                .clk(clk),
                .rst(rst),
                .h_update_en(h_update_en),
                .init_load_en_low(engine_load_en[i]),
                .init_load_en_high(engine_load_en[i+TWIN_COUNT]),
                .X_i_low(current_state_X[i]),
                .X_i_high(current_state_X[i+TWIN_COUNT]),
                .X_j(winner_X_val),
                .weight_low(weights[i]),
                .weight_high(weights[i+TWIN_COUNT]),
                .init_h_value(h_init_value),
                .E_off(current_E_off),
                .candidate_low(valid_candidates[i]),
                .candidate_high(valid_candidates[i+TWIN_COUNT]),
                .pair_rand(tree_rand[i]),
                .delta_E_low(delta_E_array[i]),
                .delta_E_high(delta_E_array[i+TWIN_COUNT]),
                .decision_low(valid_bits[i]),
                .decision_high(valid_bits[i+TWIN_COUNT]),
                .pair_valid(pair_valid_bits[i]),
                .pair_identifier(pair_identifier_bits[i]),
                .pair_delta_E(pair_delta_e_bits[i*FIELD_WIDTH +: FIELD_WIDTH])
            );
        end
    endgenerate

    // 128 independently seeded 16-bit lanes supply 2047 branch decisions:
    // 1024 for the twin layer and 1023 for the matrix selector.
    function [15:0] selector_lane_seed;
        input [31:0] master_seed;
        input integer lane;
        reg [31:0] mixed;
        reg [15:0] folded;
        begin
            mixed = master_seed ^ (32'h9E3779B9 + lane * 32'h7F4A7C15);
            mixed = mixed ^ (mixed >> 16);
            mixed = mixed ^ (mixed << 7);
            mixed = mixed ^ (mixed >> 9);
            folded = mixed[15:0] ^ mixed[31:16];
            selector_lane_seed = (folded == 16'h0000) ? 16'h0001 : folded;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            for (rng_word = 0; rng_word < (SELECTOR_WIDTH/16); rng_word = rng_word + 1)
                tree_rand[16*rng_word +: 16] <=
                    selector_lane_seed(32'h12345678, rng_word);
        end else if (|engine_load_en) begin
            for (rng_word = 0; rng_word < (SELECTOR_WIDTH/16); rng_word = rng_word + 1)
                tree_rand[16*rng_word +: 16] <=
                    selector_lane_seed(random_seed, rng_word);
        end else if (rng_US_en) begin
            for (rng_word = 0; rng_word < (SELECTOR_WIDTH/16); rng_word = rng_word + 1)
                tree_rand[16*rng_word +: 16] <= {
                    tree_rand[16*rng_word + 14 -: 15],
                    tree_rand[16*rng_word + 15] ^
                    tree_rand[16*rng_word + 13] ^
                    tree_rand[16*rng_word + 12] ^
                    tree_rand[16*rng_word + 10]
                };
        end
    end

    matrix_selector_1024_flat #(
        .FIELD_WIDTH(FIELD_WIDTH)
    ) u_selector (
        .clk(clk),
        .rst(rst),
        .valid_bits(pair_valid_bits),
        .identifier_bits(pair_identifier_bits),
        .rand_bits(tree_rand[SELECTOR_WIDTH-2:TWIN_COUNT]),
        .pair_delta_e_bits(pair_delta_e_bits),
        .final_index(matrix_winner_index),
        .final_identifier(matrix_winner_identifier),
        .final_valid(winner_found),
        .final_delta_e(final_delta_e)
    );

    // The physical dual-port memories live in BitSieve_256 so their write
    // ports can later be connected directly to the Nios V programmer. The
    // packed input presented here is already unscrambled into logical engine
    // order and retains the RAM's single-cycle read latency.

    // rng_ADB_en is retained at the interface for cycle compatibility. The
    // deterministic ADB path has no per-engine RNG state to advance.
    wire unused_rng_ADB_en = rng_ADB_en;

endmodule
