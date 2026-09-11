module e_off_generator #(
    parameter WIDTH = 28
)(
    input wire clk,
    input wire rst,             // Global System Reset

    input wire signed [WIDTH-1:0] delta_val,
    
    // --- Control Signals ---
    input wire en,              // Enable signal (from FSM: e_off_update_en)
    input wire winner_found,    // Soft Reset (from Tournament Tree: final_valid)
                                // If High: Reset E_off to 0.
                                // If Low:  Add DELTA_VAL to E_off.
    
    // --- Output ---
    output reg signed [WIDTH-1:0] E_off
);

    always @(posedge clk) begin
        if (rst) begin
            E_off <= {WIDTH{1'b0}};
        end else if (en) begin
            if (winner_found) begin
                // Case 1: A flip occurred. Reset Offset to zero immediately.
                // LEAKY BUCKET: Avoid the "Rubber Band" effect by halving the offset instead of resetting to zero.
                E_off <= E_off >> 1; //{WIDTH{1'b0}};
            end else begin
                // Case 2: No flip occurred (Local Minimum).
                // Increase Offset to lower the barrier and promote exploration.
                E_off <= E_off + delta_val;
            end
        end
    end

endmodule
