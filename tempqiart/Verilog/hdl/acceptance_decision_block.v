module acceptance_decision_block #(
    parameter DATA_WIDTH = 27,   // Width of Energy values and LUT data
    parameter ADDR_WIDTH = 10,   // Width of LFSR / LUT Address
    parameter WEIGHT_WIDTH = 16, // Width of weights
    parameter SEED = 16'hACE1
)(
    input wire clk,
    input wire rst,
    input wire rng_en,
    input wire [31:0] seed,
    // We use 'signed' inputs to ensure Verilog handles the negative math correctly
    input wire signed [DATA_WIDTH-1:0] deltaE,
    input wire signed [DATA_WIDTH-1:0] E_off,
    output wire decision
);

    // --- Internal Signals ---
    wire [WEIGHT_WIDTH-1:0] rand_addr;
    wire [DATA_WIDTH-1:0] lut_val;

    // wire [ADDR_WIDTH-1:0] rand_addr;
    // wire [7:0] lut_val;
    
    // We need an extra bit for the intermediate sum to prevent overflow 
    // before the final comparison (e.g., adding two large positive numbers).
    wire signed [DATA_WIDTH:0] calculation_result;

    // --- 1. Instantiate the Random Number Generator (LFSR) ---
    // This generates the address 'r' for the table.

    lfsr_16bit  #(
        .SEED(SEED)
    ) rng_inst (
        .clk(clk),
        .rst(rst),
        .rng_en(rng_en),
        .data_out(rand_addr)
    );

    // lfsr_16bit rng_inst (
    //     .clk(clk),
    //     .rst(rst),
    //     .seed(seed),
    //     .rng_en(rng_en),
    //     .data_out(rand_addr)
    // );

    // lfsr_10bit  #(
    //     .SEED(SEED[9:0]) // Use lower 10 bits of SEED for 10-bit LFSR
    // ) rng_inst (
    //     .clk(clk),
    //     .rst(rst),
    //     .rng_en(rng_en),
    //     .data_out(rand_addr)
    // );

    // --- 2. Instantiate the Look-Up Table (LUT) ---
    // Retrieves 'x' based on the random address 'r'.

    lookup_table #(
        .N(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH)
    ) lut_inst (
        .addr(rand_addr[ADDR_WIDTH-1:0]), // Use only the lower ADDR_WIDTH bits of rand_addr
        .data_out(lut_val)
    );

    // lookup_table #(
    //     .N(ADDR_WIDTH), 
    //     .DATA_WIDTH(8) // We only need 8 bits for the LUT output
    // ) lut_inst (
    //     .addr(rand_addr), // rand_addr is already ADDR_WIDTH bits
    //     .data_out(lut_val)
    // );

    // --- 3. Arithmetic Logic & Decision ---
    // Equation: (-deltaE) + E_off + x
    // Note: We extend inputs to DATA_WIDTH + 1 to handle potential carry/overflow safely.
    assign calculation_result = E_off - deltaE + $signed({1'b0, lut_val});

    // Check if result >= 0.
    // In 2's complement, if the MSB (Sign Bit) is 0, the number is positive or zero.
    // If the MSB is 1, the number is negative.
    assign decision = ~calculation_result[DATA_WIDTH]; 

endmodule