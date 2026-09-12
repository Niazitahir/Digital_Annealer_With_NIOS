module tabu_mask_generator #(
    parameter MAX_DEPTH = 2048,
    parameter INDEX_WIDTH = 11,
    parameter MASK_WIDTH = 2048,
    parameter ZERO_BITS  = 2048
)(
    input wire clk,
    input wire rst,
    input wire shift_en,                      // Asserted when a valid flip occurs
    input wire [INDEX_WIDTH-1:0] new_index,   // The winning index to lock out
    input wire [INDEX_WIDTH-1:0] depth,       // Runtime lockout depth, 0..2047
    output wire [MASK_WIDTH-1:0] tabu_mask_gated
);

    // Internal Shift Registers
    reg [INDEX_WIDTH-1:0] history_idx [0:MAX_DEPTH-1];
    reg                   history_val [0:MAX_DEPTH-1];

    // The combined lockout mask, updated incrementally instead of being
    // recomputed from every history entry on every cycle.
    reg [MASK_WIDTH-1:0] tabu_mask;

    // Only the entry at depth-1 can leave the runtime-sized window during a
    // shift. A masked index is not selected again while it remains tabu.
    wire [INDEX_WIDTH-1:0] evict_pos = depth - 1'b1;
    wire [INDEX_WIDTH-1:0] evict_index = history_idx[evict_pos];
    wire evict_active = shift_en &&
                        (depth != {INDEX_WIDTH{1'b0}}) &&
                        history_val[evict_pos];

    integer i;

    // 1. Shift Register Logic (The Circular Buffer)
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < MAX_DEPTH; i = i + 1) begin
                history_idx[i] <= {INDEX_WIDTH{1'b0}};
                history_val[i] <= 1'b0; // Invalid at startup
            end
            tabu_mask <= {MASK_WIDTH{1'b0}};
        end else if (shift_en) begin
            // Shift everything down by 1
            for (i = MAX_DEPTH-1; i > 0; i = i - 1) begin
                history_idx[i] <= history_idx[i-1];
                history_val[i] <= history_val[i-1];
            end
            // Insert the new winning index at the top
            history_idx[0] <= new_index;
            history_val[0] <= 1'b1;

            tabu_mask[new_index] <= 1'b1;
            if (evict_active)
                tabu_mask[evict_index] <= 1'b0;
        end
    end

    // ZERO_BITS == MASK_WIDTH for the current caller, so no additional
    // permanently masked bits are required here.
    assign tabu_mask_gated = tabu_mask;

endmodule
