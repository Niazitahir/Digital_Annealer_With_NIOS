`timescale 1ns/1ps

module tb_update_selector_1024_flat_equiv;
    reg clk;
    reg rst;
    reg [1023:0] valid_bits;
    reg [1022:0] rand_bits;
    wire [9:0] reference_index;
    wire reference_valid;
    wire [9:0] flat_index;
    wire flat_valid;

    integer seed;
    integer vector_number;
    integer word_number;
    integer singleton;

    update_selector_32 reference_selector (
        .clk(clk), .rst(rst), .valid_bits(valid_bits),
        .rand_bits(rand_bits), .final_index(reference_index),
        .final_valid(reference_valid)
    );

    update_selector_1024_flat flat_selector (
        .clk(clk), .rst(rst), .valid_bits(valid_bits),
        .rand_bits(rand_bits), .final_index(flat_index),
        .final_valid(flat_valid)
    );

    always #5 clk = ~clk;

    task randomize_inputs;
        begin
            for (word_number = 0; word_number < 32; word_number = word_number + 1)
                valid_bits[word_number*32 +: 32] = $random(seed);
            for (word_number = 0; word_number < 31; word_number = word_number + 1)
                rand_bits[word_number*32 +: 32] = $random(seed);
            rand_bits[1022:992] = $random(seed);
        end
    endtask

    task compare_outputs;
        input [31:0] test_number;
        begin
            #1;
            if ((flat_valid !== reference_valid) ||
                (flat_index !== reference_index)) begin
                $display("FAIL vector %0d: reference %b/%0d, flat %b/%0d",
                    test_number, reference_valid, reference_index,
                    flat_valid, flat_index);
                $finish;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        valid_bits = 1024'd0;
        rand_bits = 1023'd0;
        seed = 32'h49651024;
        vector_number = 0;

        repeat (2) begin
            @(negedge clk); randomize_inputs;
            @(posedge clk); compare_outputs(vector_number);
            vector_number = vector_number + 1;
        end
        rst = 1'b0;

        @(negedge clk); valid_bits = 1024'd0; rand_bits = {1023{1'b1}};
        @(posedge clk); compare_outputs(vector_number);
        vector_number = vector_number + 1;

        for (singleton = 0; singleton < 1024; singleton = singleton + 1) begin
            @(negedge clk);
            valid_bits = 1024'd0;
            valid_bits[singleton] = 1'b1;
            for (word_number = 0; word_number < 31; word_number = word_number + 1)
                rand_bits[word_number*32 +: 32] = $random(seed);
            rand_bits[1022:992] = $random(seed);
            @(posedge clk); compare_outputs(vector_number);
            vector_number = vector_number + 1;
        end

        while (vector_number < 2048) begin
            @(negedge clk); randomize_inputs;
            @(posedge clk); compare_outputs(vector_number);
            vector_number = vector_number + 1;
        end

        $display("PASS: %0d selector equivalence vectors", vector_number);
        $finish;
    end
endmodule
