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

    // The combined lockout mask
    reg [MASK_WIDTH-1:0] tabu_mask;

    wire [INDEX_WIDTH:0] effective_depth = {1'b0, depth};
    
    integer i, j;

    // 1. Shift Register Logic (The Circular Buffer)
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < MAX_DEPTH; i = i + 1) begin
                history_idx[i] <= {INDEX_WIDTH{1'b0}};
                history_val[i] <= 1'b0; // Invalid at startup
            end
        end else if (shift_en) begin
            // Shift everything down by 1
            for (i = MAX_DEPTH-1; i > 0; i = i - 1) begin
                history_idx[i] <= history_idx[i-1];
                history_val[i] <= history_val[i-1];
            end
            // Insert the new winning index at the top
            history_idx[0] <= new_index;
            history_val[0] <= 1'b1;
        end
    end

    // 2. Combinational Mask Generation
    always @(*) begin
        // Initialize mask to all zeros
        tabu_mask = {MASK_WIDTH{1'b0}};
        
        // OR the decoded one-hot indices together
        for (j = 0; j < MAX_DEPTH; j = j + 1) begin
            if ((j < effective_depth) && history_val[j]) begin
                tabu_mask[history_idx[j]] = 1'b1; // Lock out this specific bit
            end
        end
    end

    // Indices at or above ZERO_BITS are permanently masked.  top.v passes
    // MASK_WIDTH here and applies its runtime active-engine mask separately.
    assign tabu_mask_gated = tabu_mask | ({MASK_WIDTH{1'b1}} << ZERO_BITS);

endmodule
