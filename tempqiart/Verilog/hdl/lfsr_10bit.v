module lfsr_10bit #(
    parameter SEED = 10'h1AB // Default non-zero seed
)(
    input wire clk,
    input wire rst,
    input wire rng_en,
    // The output is the 10-bit 'random' number
    output reg [9:0] data_out
);

    // Internal Register
    // I initialized this to 0xFFFF (all 1s) to ensure the taps catch a non-zero value.
    // If initialized to 10'd1 (only bit 0 is 1), and taps exclude bit 0, 
    // the '1' would shift out instantly, killing the LFSR.

    // safe initialization of the output
    initial data_out = SEED;

    // Sequential Logic
    always @(posedge clk) begin
        if (rst) begin
            data_out <= SEED; // Reset to non-zero seed
        end else
        if (rng_en) begin
            data_out <= {data_out[8:0], data_out[9] ^ data_out[2]};
        end
    end

endmodule