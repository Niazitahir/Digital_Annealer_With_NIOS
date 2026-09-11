`timescale 1ns / 1ps
`default_nettype none

// One complete per-bit Bit-Sieve datapath.
//
// This module combines the two conditional negators, the loadable local-field
// accumulator, and the deterministic (LUT value = 0) acceptance decision. The
// state bits are supplied separately so a top-level generate loop can connect
// X_i to current_state_X[i] and X_j to current_state_X[winner_index].
module unified_BitSieve_Engine #(
    parameter ISING_WIDTH = 28,
    parameter WEIGHT_WIDTH = 17
)(
    input wire clk,
    input wire rst,

    // Local-field register controls. Initialization has priority over update.
    input wire h_update_en,
    input wire init_load_en,

    // Current state of this engine i and of the selected winner j.
    input wire X_i,
    input wire X_j,

    // Q[i][j], the precomputed initial h_i, and the global energy offset.
    input wire signed [WEIGHT_WIDTH-1:0] weight,
    input wire signed [ISING_WIDTH-1:0] init_h_value,
    input wire signed [ISING_WIDTH-1:0] E_off,

    output wire signed [ISING_WIDTH-1:0] delta_E,
    output wire decision
);

    // DeGloria local-field update:
    //   X_j = 1 (the committed flip was 0->1): add W_ij
    //   X_j = 0 (the committed flip was 1->0): subtract W_ij
    // Negation intentionally remains WEIGHT_WIDTH wide, exactly matching the
    // legacy conditional_inverter_neg0 before sign extension.
    wire signed [WEIGHT_WIDTH-1:0] delta_h;
    wire signed [ISING_WIDTH-1:0] delta_h_extended;

    assign delta_h = X_j ? weight : -weight;
    assign delta_h_extended = {
        {(ISING_WIDTH-WEIGHT_WIDTH){delta_h[WEIGHT_WIDTH-1]}},
        delta_h
    };

    // Current local field h_i. Reset and load/update behavior is cycle-for-
    // cycle identical to accumulator_loadable.
    reg signed [ISING_WIDTH-1:0] local_field;

    always @(posedge clk) begin
        if (rst) begin
            local_field <= {ISING_WIDTH{1'b0}};
        end else if (init_load_en) begin
            local_field <= init_h_value;
        end else if (h_update_en) begin
            local_field <= local_field + delta_h_extended;
        end
    end

    // Matsubara Eq. (2): delta_E_i = -(1 - 2*X_i) * h_i.
    // X_i=1 passes h_i; X_i=0 negates it at ISING_WIDTH, preserving the
    // legacy two's-complement overflow behavior for the most-negative value.
    assign delta_E = X_i ? local_field : -local_field;

    assign decision = (E_off > delta_E);

endmodule

`default_nettype wire
