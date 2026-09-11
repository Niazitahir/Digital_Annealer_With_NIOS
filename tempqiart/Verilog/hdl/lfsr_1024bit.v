module lfsr_1024bit #(
    parameter SEED = 32'hACE11ECA // Default non-zero seed
)(
    input  wire clk,
    input  wire rst, 
    input wire rng_en,
    output reg [1024:1] data_out // 1024-bit shift register
);
    // safe initialization of the output
    initial data_out = SEED;

    // The feedback bit is the bit that "falls off" the end (bit 1)
    wire fb = data_out[1];

    always @(posedge clk) begin
        if (rst) begin
            // LFSR must be initialized to a non-zero value
            data_out <= SEED; 
        end else if (rng_en) begin
            // Shift all bits down by default
            data_out[1023:1] <= data_out[1024:2];
            
            // Apply Galois feedback XORs at the specific taps
            // The bit at 'n' becomes (bit n+1 XOR fb)
            data_out[1024] <= fb;
            data_out[19]   <= data_out[20] ^ fb;
            data_out[6]    <= data_out[7]  ^ fb;
            data_out[1]    <= data_out[2]  ^ fb;
        end
    end

endmodule
