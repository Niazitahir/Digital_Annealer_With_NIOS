`timescale 1ns / 1ps
`default_nettype none

// Two logical Bit-Sieve engines sharing one hierarchy instance.
//
// Twin i owns logical engines i and i+1024. The two local-field registers and
// delta-E paths remain independent. The first randomized tournament layer is
// folded into this module so only 1024 valid/identifier pairs leave the array.
module twin_unified_BitSieve_Engine #(
    parameter FIELD_WIDTH = 28,
    parameter WEIGHT_WIDTH = 10
)(
    input wire clk,
    input wire rst,
    input wire h_update_en,
    input wire init_load_en_low,
    input wire init_load_en_high,
    input wire X_i_low,
    input wire X_i_high,
    input wire X_j,
    input wire signed [WEIGHT_WIDTH-1:0] weight_low,
    input wire signed [WEIGHT_WIDTH-1:0] weight_high,
    input wire signed [FIELD_WIDTH-1:0] init_h_value,
    input wire signed [FIELD_WIDTH-1:0] E_off,
    input wire candidate_low,
    input wire candidate_high,
    input wire pair_rand,
    output wire signed [FIELD_WIDTH-1:0] delta_E_low,
    output wire signed [FIELD_WIDTH-1:0] delta_E_high,
    output wire decision_low,
    output wire decision_high,
    output wire pair_valid,
    output wire pair_identifier
);

    // The extra arithmetic bit makes negation of the legal 10-bit value -512
    // exact (+512) instead of wrapping in a 10-bit temporary.
    wire signed [WEIGHT_WIDTH:0] weight_low_extended;
    wire signed [WEIGHT_WIDTH:0] weight_high_extended;
    reg  signed [FIELD_WIDTH-1:0] local_field_low;
    reg  signed [FIELD_WIDTH-1:0] local_field_high;

    assign weight_low_extended = {weight_low[WEIGHT_WIDTH-1], weight_low};
    assign weight_high_extended = {weight_high[WEIGHT_WIDTH-1], weight_high};

    always @(posedge clk) begin
        if (rst) begin
            local_field_low <= {FIELD_WIDTH{1'b0}};
            local_field_high <= {FIELD_WIDTH{1'b0}};
        end else begin
            if (init_load_en_low)
                local_field_low <= init_h_value;
            else if (h_update_en) begin
                if (X_j)
                    local_field_low <= local_field_low + weight_low_extended;
                else
                    local_field_low <= local_field_low - weight_low_extended;
            end

            if (init_load_en_high)
                local_field_high <= init_h_value;
            else if (h_update_en) begin
                if (X_j)
                    local_field_high <= local_field_high + weight_high_extended;
                else
                    local_field_high <= local_field_high - weight_high_extended;
            end
        end
    end

    assign delta_E_low = X_i_low ? local_field_low : -local_field_low;
    assign delta_E_high = X_i_high ? local_field_high : -local_field_high;

    assign decision_low = (E_off > delta_E_low);
    assign decision_high = (E_off > delta_E_high);

    // Existing convention: when both candidates are valid, pair_rand=1 picks
    // the lower/left candidate. The identifier is irrelevant when valid=0.
    assign pair_valid = candidate_low | candidate_high;
    assign pair_identifier = (candidate_low && candidate_high)
        ? ~pair_rand : candidate_high;

endmodule

`default_nettype wire
