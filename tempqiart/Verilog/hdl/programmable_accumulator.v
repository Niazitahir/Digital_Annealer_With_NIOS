module accumulator_loadable #(parameter WIDTH=27) (
    input wire clk,
    input wire rst,
    
    // Operation Signals
    input wire en,                   // Normal Accumulate (Q = Q + D)
    input wire load_en,              // Initialization Load (Q = init_val)
    
    // Data Signals
    input wire signed [WIDTH-1:0] D,        // Delta h input
    input wire signed [WIDTH-1:0] init_val, // Precomputed initial value
    
    output reg signed [WIDTH-1:0] Q
);
    always @(posedge clk) begin
        if (rst) begin
            Q <= {WIDTH{1'b0}};
        end else if (load_en) begin
            // Priority: Load overrides accumulation
            Q <= init_val;
        end else if (en) begin
            Q <= Q + D;
        end
    end
endmodule