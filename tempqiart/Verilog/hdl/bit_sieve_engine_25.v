// Bit Sieve Engine with Loadable Accumulator
module bitSieve_engine #(
    parameter N = 1024,
    parameter INDEX_WIDTH = 10,
    parameter ISING_WIDTH = 28,
    parameter WEIGHT_WIDTH = 17

)(
    input wire clk,
    input wire rst,
    
    // --- Control Signals --- //
    input wire h_update_en,     // Normal update enable
    input wire init_load_en,    // High when initializing THIS engine
    
    // --- State Inputs --- //
    input wire X_i,             
    input wire X_j,             
    input wire [INDEX_WIDTH-1:0] idx_j,     
    
    // --- Data Inputs --- //
    input wire [WEIGHT_WIDTH-1:0] weight,
    input wire signed [ISING_WIDTH-1:0] init_h_value, // Precomputed h_i
    
    // --- Output --- //
    output wire signed [ISING_WIDTH-1:0] delta_E
);

    // --- Internal Signals --- //
    wire signed [WEIGHT_WIDTH-1:0] delta_h;         // The value to add to the accumulator
    wire signed [ISING_WIDTH-1:0] h_i;             // The current local field value

    // ---------------------------------------------------------
    // Delta h Calculation (Conditional Inverter #1)
    // ---------------------------------------------------------
    // If neighbor X_j flipped 0->1 (Logic 1), we ADD the weight.
    // If neighbor X_j flipped 1->0 (Logic 0), we SUBTRACT the weight.
    // Note: We sign-extend the 16-bit weight to matches the accumulator width if needed,
    // but the accumulator handles the addition. The Inverter just handles the sign.
    
    conditional_inverter_neg0 #(
        .WIDTH(WEIGHT_WIDTH)
    ) inv_weight (
        .Din(weight),
        .Sel(X_j),
        .Dout(delta_h) // This is delta_h_i
    );

    // ---------------------------------------------------------
    // Local Field Accumulator
    // ---------------------------------------------------------
    accumulator_loadable #(
        .WIDTH(ISING_WIDTH)
    ) acc_h_i (
        .clk(clk),
        .rst(rst),
        .en(h_update_en),
        .load_en(init_load_en),      // Connect load enable
        .D({{ISING_WIDTH-WEIGHT_WIDTH{delta_h[WEIGHT_WIDTH-1]}}, delta_h}),
        .init_val(init_h_value),     // Connect load data
        .Q(h_i)
    );

    // ---------------------------------------------------------
    // Delta E Calculation (Conditional Inverter #2)
    // ---------------------------------------------------------
    // Paper Eq (2): Delta E_i = -(1 - 2x_i) * h_i
    // If x_i = 1: Delta E_i = +h_i
    // If x_i = 0: Delta E_i = -h_i
    // This maps exactly to our conditional inverter (Sel=1 -> pass, Sel=0 -> negate).
    
    conditional_inverter_neg0 #(
        .WIDTH(ISING_WIDTH)
    ) inv_energy (
        .Din(h_i),
        .Sel(X_i),
        .Dout(delta_E)
    );

endmodule
