// Ten-level, 1024-input pairwise randomized selector.
// The synchronization register is exactly halfway through the tree, after
// layer five (1024 -> 32), leaving five combinational layers after it.
module update_selector_32 (
    input wire clk,
    input wire rst,
    input wire [1023:0] valid_bits,
    input wire [1022:0] rand_bits,
    output wire [9:0] final_index,
    output wire final_valid
);
    genvar i;

    wire [9:0] idx_L1 [0:511]; wire val_L1 [0:511];
    wire [9:0] idx_L2 [0:255]; wire val_L2 [0:255];
    wire [9:0] idx_L3 [0:127]; wire val_L3 [0:127];
    wire [9:0] idx_L4 [0:63];  wire val_L4 [0:63];
    wire [9:0] idx_L5 [0:31];  wire val_L5 [0:31];

    reg [9:0] pipe_idx_L5 [0:31];
    reg       pipe_val_L5 [0:31];

    wire [9:0] idx_L6 [0:15]; wire val_L6 [0:15];
    wire [9:0] idx_L7 [0:7];  wire val_L7 [0:7];
    wire [9:0] idx_L8 [0:3];  wire val_L8 [0:3];
    wire [9:0] idx_L9 [0:1];  wire val_L9 [0:1];

    generate for (i = 0; i < 512; i = i + 1) begin : L1
        localparam [9:0] idxA = 2*i;
        localparam [9:0] idxB = 2*i + 1;
        randomized_selector_2to1 #(10) mux (
            .indexA(idxA), .vA(valid_bits[2*i]),
            .indexB(idxB), .vB(valid_bits[2*i+1]),
            .rand_bit(rand_bits[i]), .indexO(idx_L1[i]), .vO(val_L1[i])
        );
    end endgenerate

    generate for (i = 0; i < 256; i = i + 1) begin : L2
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L1[2*i]), .vA(val_L1[2*i]),
            .indexB(idx_L1[2*i+1]), .vB(val_L1[2*i+1]),
            .rand_bit(rand_bits[512+i]), .indexO(idx_L2[i]), .vO(val_L2[i])
        );
    end endgenerate

    generate for (i = 0; i < 128; i = i + 1) begin : L3
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L2[2*i]), .vA(val_L2[2*i]),
            .indexB(idx_L2[2*i+1]), .vB(val_L2[2*i+1]),
            .rand_bit(rand_bits[768+i]), .indexO(idx_L3[i]), .vO(val_L3[i])
        );
    end endgenerate

    generate for (i = 0; i < 64; i = i + 1) begin : L4
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L3[2*i]), .vA(val_L3[2*i]),
            .indexB(idx_L3[2*i+1]), .vB(val_L3[2*i+1]),
            .rand_bit(rand_bits[896+i]), .indexO(idx_L4[i]), .vO(val_L4[i])
        );
    end endgenerate

    generate for (i = 0; i < 32; i = i + 1) begin : L5
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L4[2*i]), .vA(val_L4[2*i]),
            .indexB(idx_L4[2*i+1]), .vB(val_L4[2*i+1]),
            .rand_bit(rand_bits[960+i]), .indexO(idx_L5[i]), .vO(val_L5[i])
        );
    end endgenerate

    integer j;
    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < 32; j = j + 1) begin
                pipe_idx_L5[j] <= 10'd0;
                pipe_val_L5[j] <= 1'b0;
            end
        end else begin
            for (j = 0; j < 32; j = j + 1) begin
                pipe_idx_L5[j] <= idx_L5[j];
                pipe_val_L5[j] <= val_L5[j];
            end
        end
    end

    generate for (i = 0; i < 16; i = i + 1) begin : L6
        randomized_selector_2to1 #(10) mux (
            .indexA(pipe_idx_L5[2*i]), .vA(pipe_val_L5[2*i]),
            .indexB(pipe_idx_L5[2*i+1]), .vB(pipe_val_L5[2*i+1]),
            .rand_bit(rand_bits[992+i]), .indexO(idx_L6[i]), .vO(val_L6[i])
        );
    end endgenerate

    generate for (i = 0; i < 8; i = i + 1) begin : L7
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L6[2*i]), .vA(val_L6[2*i]),
            .indexB(idx_L6[2*i+1]), .vB(val_L6[2*i+1]),
            .rand_bit(rand_bits[1008+i]), .indexO(idx_L7[i]), .vO(val_L7[i])
        );
    end endgenerate

    generate for (i = 0; i < 4; i = i + 1) begin : L8
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L7[2*i]), .vA(val_L7[2*i]),
            .indexB(idx_L7[2*i+1]), .vB(val_L7[2*i+1]),
            .rand_bit(rand_bits[1016+i]), .indexO(idx_L8[i]), .vO(val_L8[i])
        );
    end endgenerate

    generate for (i = 0; i < 2; i = i + 1) begin : L9
        randomized_selector_2to1 #(10) mux (
            .indexA(idx_L8[2*i]), .vA(val_L8[2*i]),
            .indexB(idx_L8[2*i+1]), .vB(val_L8[2*i+1]),
            .rand_bit(rand_bits[1020+i]), .indexO(idx_L9[i]), .vO(val_L9[i])
        );
    end endgenerate

    randomized_selector_2to1 #(10) mux_final (
        .indexA(idx_L9[0]), .vA(val_L9[0]),
        .indexB(idx_L9[1]), .vB(val_L9[1]),
        .rand_bit(rand_bits[1022]),
        .indexO(final_index), .vO(final_valid)
    );
endmodule

