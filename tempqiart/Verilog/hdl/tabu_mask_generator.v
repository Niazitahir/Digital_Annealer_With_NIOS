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

    // Circular history buffer backed by inferred block RAM instead of a
    // MAX_DEPTH-entry shift-register array (which Quartus's shift-register
    // recognition maps to MLABs, i.e. the same LAB budget as combinational
    // logic). The eviction candidate is continuously prefetched one cycle
    // ahead so the BRAM's synchronous read latency never adds a cycle to
    // the actual insertion/eviction event -- this relies on shift_en never
    // asserting on two consecutive clock cycles, which the multi-cycle FSM
    // iteration (RNG/select/update pipeline) between accepted flips already
    // guarantees.
    (* ramstyle = "M20K" *) reg [INDEX_WIDTH-1:0] history_ram [0:MAX_DEPTH-1];

    reg [INDEX_WIDTH-1:0] wr_ptr;
    reg [INDEX_WIDTH:0]   fill_count;   // counts insertions so far, saturates at MAX_DEPTH
    reg [MASK_WIDTH-1:0]  tabu_mask;

    // What would be evicted if a shift happened this cycle, using the
    // current (not-yet-updated) wr_ptr/depth. Re-issued every cycle so the
    // result is already valid by the time an actual shift needs it.
    wire [INDEX_WIDTH-1:0] evict_read_ptr = wr_ptr - depth;
    reg  [INDEX_WIDTH-1:0] evict_index_prefetched;
    reg                    evict_valid_prefetched;

    always @(posedge clk) begin
        if (rst) begin
            evict_index_prefetched <= {INDEX_WIDTH{1'b0}};
            evict_valid_prefetched <= 1'b0;
        end else begin
            evict_index_prefetched <= history_ram[evict_read_ptr];
            evict_valid_prefetched <= (depth != {INDEX_WIDTH{1'b0}}) &&
                                       (fill_count >= depth);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr     <= {INDEX_WIDTH{1'b0}};
            fill_count <= {(INDEX_WIDTH+1){1'b0}};
            tabu_mask  <= {MASK_WIDTH{1'b0}};
        end else if (shift_en) begin
            history_ram[wr_ptr] <= new_index;

            wr_ptr <= wr_ptr + 1'b1;
            if (fill_count < MAX_DEPTH)
                fill_count <= fill_count + 1'b1;

            tabu_mask[new_index] <= 1'b1;
            if (evict_valid_prefetched)
                tabu_mask[evict_index_prefetched] <= 1'b0;
        end
    end

    // ZERO_BITS == MASK_WIDTH for the current caller, so no additional
    // permanently masked bits are required here.
    assign tabu_mask_gated = tabu_mask;

endmodule
