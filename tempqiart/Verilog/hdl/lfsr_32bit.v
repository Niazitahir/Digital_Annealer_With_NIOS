module lfsr_32bit #(
    parameter SEED = 32'hACE11ECA // Default non-zero seed
)(
    input wire clk,
    input wire rst,
    input wire rng_en,
    // The output is the 32-bit 'random' number
    output reg [31:0] data_out
);

    // Internal Register
    // I initialized this to 0xFFFF (all 1s) to ensure the taps catch a non-zero value.
    // If initialized to 16'd1 (only bit 0 is 1), and taps exclude bit 0, 
    // the '1' would shift out instantly, killing the LFSR.

    // safe initialization of the output
    initial data_out = SEED;

    // Sequential Logic
    always @(posedge clk) begin
        if (rst) begin
            data_out <= SEED; // Reset to non-zero seed
        end else
        // Right shift: bits [15:1] move to [14:0]
        // The Feedback result is shifted into the MSB (Bit 15)
        if (rng_en) begin
            data_out <= {data_out[30:0], data_out[15] ^ data_out[6] ^ data_out[5] ^ data_out[1]};
        end
    end

endmodule