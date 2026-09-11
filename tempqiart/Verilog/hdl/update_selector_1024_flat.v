// ModelSim-optimized equivalent of the 1024-input pairwise selector tree.
// It preserves the exact branch/random-bit mapping and the layer-five register
// of update_selector_32 without instantiating 1023 selector submodules.
module update_selector_1024_flat (
    input wire clk,
    input wire rst,
    input wire [1023:0] valid_bits,
    input wire [1022:0] rand_bits,
    output wire [9:0] final_index,
    output wire final_valid
);
    function [10:0] select_pair;
        input [9:0] index_a;
        input valid_a;
        input [9:0] index_b;
        input valid_b;
        input random_bit;
        reg [9:0] selected_index;
        begin
            if (valid_a && valid_b)
                selected_index = random_bit ? index_a : index_b;
            else if (valid_a)
                selected_index = index_a;
            else if (valid_b)
                selected_index = index_b;
            else
                selected_index = 10'd0;
            select_pair = {valid_a | valid_b, selected_index};
        end
    endfunction

    reg [9:0] pre_index [0:1023];
    reg pre_valid [0:1023];
    reg [9:0] pipe_index [0:31];
    reg pipe_valid [0:31];
    reg [9:0] post_index [0:31];
    reg post_valid [0:31];
    reg [9:0] final_index_comb;
    reg final_valid_comb;

    integer pre_i;
    integer pipe_i;
    integer post_i;

    // Layers 1..5: 1024 -> 512 -> 256 -> 128 -> 64 -> 32.
    always @(*) begin
        for (pre_i = 0; pre_i < 1024; pre_i = pre_i + 1) begin
            pre_index[pre_i] = pre_i;
            pre_valid[pre_i] = valid_bits[pre_i];
        end

        for (pre_i = 0; pre_i < 512; pre_i = pre_i + 1)
            {pre_valid[pre_i], pre_index[pre_i]} = select_pair(
                pre_index[2*pre_i], pre_valid[2*pre_i],
                pre_index[2*pre_i+1], pre_valid[2*pre_i+1], rand_bits[pre_i]);

        for (pre_i = 0; pre_i < 256; pre_i = pre_i + 1)
            {pre_valid[pre_i], pre_index[pre_i]} = select_pair(
                pre_index[2*pre_i], pre_valid[2*pre_i],
                pre_index[2*pre_i+1], pre_valid[2*pre_i+1], rand_bits[512+pre_i]);

        for (pre_i = 0; pre_i < 128; pre_i = pre_i + 1)
            {pre_valid[pre_i], pre_index[pre_i]} = select_pair(
                pre_index[2*pre_i], pre_valid[2*pre_i],
                pre_index[2*pre_i+1], pre_valid[2*pre_i+1], rand_bits[768+pre_i]);

        for (pre_i = 0; pre_i < 64; pre_i = pre_i + 1)
            {pre_valid[pre_i], pre_index[pre_i]} = select_pair(
                pre_index[2*pre_i], pre_valid[2*pre_i],
                pre_index[2*pre_i+1], pre_valid[2*pre_i+1], rand_bits[896+pre_i]);

        for (pre_i = 0; pre_i < 32; pre_i = pre_i + 1)
            {pre_valid[pre_i], pre_index[pre_i]} = select_pair(
                pre_index[2*pre_i], pre_valid[2*pre_i],
                pre_index[2*pre_i+1], pre_valid[2*pre_i+1], rand_bits[960+pre_i]);
    end

    always @(posedge clk) begin
        if (rst) begin
            for (pipe_i = 0; pipe_i < 32; pipe_i = pipe_i + 1) begin
                pipe_index[pipe_i] <= 10'd0;
                pipe_valid[pipe_i] <= 1'b0;
            end
        end else begin
            for (pipe_i = 0; pipe_i < 32; pipe_i = pipe_i + 1) begin
                pipe_index[pipe_i] <= pre_index[pipe_i];
                pipe_valid[pipe_i] <= pre_valid[pipe_i];
            end
        end
    end

    // Layers 6..10: 32 -> 16 -> 8 -> 4 -> 2 -> 1.
    always @(*) begin
        for (post_i = 0; post_i < 32; post_i = post_i + 1) begin
            post_index[post_i] = pipe_index[post_i];
            post_valid[post_i] = pipe_valid[post_i];
        end

        for (post_i = 0; post_i < 16; post_i = post_i + 1)
            {post_valid[post_i], post_index[post_i]} = select_pair(
                post_index[2*post_i], post_valid[2*post_i],
                post_index[2*post_i+1], post_valid[2*post_i+1], rand_bits[992+post_i]);

        for (post_i = 0; post_i < 8; post_i = post_i + 1)
            {post_valid[post_i], post_index[post_i]} = select_pair(
                post_index[2*post_i], post_valid[2*post_i],
                post_index[2*post_i+1], post_valid[2*post_i+1], rand_bits[1008+post_i]);

        for (post_i = 0; post_i < 4; post_i = post_i + 1)
            {post_valid[post_i], post_index[post_i]} = select_pair(
                post_index[2*post_i], post_valid[2*post_i],
                post_index[2*post_i+1], post_valid[2*post_i+1], rand_bits[1016+post_i]);

        for (post_i = 0; post_i < 2; post_i = post_i + 1)
            {post_valid[post_i], post_index[post_i]} = select_pair(
                post_index[2*post_i], post_valid[2*post_i],
                post_index[2*post_i+1], post_valid[2*post_i+1], rand_bits[1020+post_i]);

        {final_valid_comb, final_index_comb} = select_pair(
            post_index[0], post_valid[0], post_index[1], post_valid[1], rand_bits[1022]);
    end

    assign final_index = final_index_comb;
    assign final_valid = final_valid_comb;
endmodule
