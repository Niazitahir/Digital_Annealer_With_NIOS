// Combined QUBO weight ROM for the parallel Bit-Sieve engines.
//
// Address j stores Q[0][j] through Q[ENGINE_COUNT-1][j] in one wide word.
// Engine i is mapped to q[(i * WEIGHT_WIDTH) +: WEIGHT_WIDTH], so engine 0
// occupies the least-significant 16 bits with the default parameters.
//
// The synchronous read deliberately matches the existing altsyncram row ROMs:
// an address sampled on a rising clock edge appears on q after that edge.
module qubo_weight_rom #(
    parameter integer ENGINE_COUNT = 1024,
    parameter integer WEIGHT_WIDTH = 18,
    parameter integer ADDRESS_WIDTH = 10,
    parameter integer DEPTH = 1024,
    parameter INIT_FILE = "../memoy/qubo_weights_1024x18432.mem"
)(
    input  wire [ADDRESS_WIDTH-1:0] address,
    input  wire                     clock,
    output reg  [(ENGINE_COUNT * WEIGHT_WIDTH)-1:0] q
);

    localparam integer ROW_WIDTH = ENGINE_COUNT * WEIGHT_WIDTH;

    reg [ROW_WIDTH-1:0] memory [0:DEPTH-1];

    initial begin
        $readmemh(INIT_FILE, memory);
    end

    always @(posedge clock) begin
        q <= memory[address];
    end

endmodule
