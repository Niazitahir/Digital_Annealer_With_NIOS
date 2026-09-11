// 1024-input Boolean-path matrix selector.
//
// The candidates are viewed as 32 rows of 32 columns. Each row first selects
// one five-bit column index using a Boolean decision path. The 32 row-valid
// bits and column indices are then registered. A second 32-input selector
// chooses the five-bit row index and carries the winning row's column index in
// parallel, producing {row, column} without routing ten-bit indices through
// all 1023 tournament nodes.
//
// Random-bit allocation matches update_selector_1024_flat exactly:
//   layer 1:    0..511       layer 6:   992..1007
//   layer 2:  512..767       layer 7:  1008..1015
//   layer 3:  768..895       layer 8:  1016..1019
//   layer 4:  896..959       layer 9:  1020..1021
//   layer 5:  960..991       layer 10: 1022
module matrix_selector_1024_flat (
    input  wire          clk,
    input  wire          rst,
    input  wire [1023:0] valid_bits,
    input  wire [1023:0] identifier_bits,
    input  wire [1022:0] rand_bits,
    output wire [9:0]    final_index,
    output wire          final_identifier,
    output wire          final_valid
);

    // Return {valid, identifier payload, five-bit selected index} for one row.
    // A right-path bit is stored at every node instead of propagating a full
    // index. The existing selector convention is retained: when both inputs
    // are valid, random_bit=1 selects the left input.
    function [6:0] select_32_path;
        input [31:0] candidates;
        input [31:0] identifiers;
        input [30:0] random_bits;
        reg [15:0] valid_l1;
        reg [15:0] right_l1;
        reg [7:0]  valid_l2;
        reg [7:0]  right_l2;
        reg [3:0]  valid_l3;
        reg [3:0]  right_l3;
        reg [1:0]  valid_l4;
        reg [1:0]  right_l4;
        reg        valid_l5;
        reg        right_l5;
        reg [15:0] identifier_l1;
        reg [7:0]  identifier_l2;
        reg [3:0]  identifier_l3;
        reg [1:0]  identifier_l4;
        reg        identifier_l5;
        reg [4:0]  selected_index;
        integer k;
        begin
            for (k = 0; k < 16; k = k + 1) begin
                valid_l1[k] = candidates[2*k] | candidates[2*k+1];
                right_l1[k] = (candidates[2*k] && candidates[2*k+1])
                    ? ~random_bits[k] : candidates[2*k+1];
                identifier_l1[k] = right_l1[k]
                    ? identifiers[2*k+1] : identifiers[2*k];
            end

            for (k = 0; k < 8; k = k + 1) begin
                valid_l2[k] = valid_l1[2*k] | valid_l1[2*k+1];
                right_l2[k] = (valid_l1[2*k] && valid_l1[2*k+1])
                    ? ~random_bits[16+k] : valid_l1[2*k+1];
                identifier_l2[k] = right_l2[k]
                    ? identifier_l1[2*k+1] : identifier_l1[2*k];
            end

            for (k = 0; k < 4; k = k + 1) begin
                valid_l3[k] = valid_l2[2*k] | valid_l2[2*k+1];
                right_l3[k] = (valid_l2[2*k] && valid_l2[2*k+1])
                    ? ~random_bits[24+k] : valid_l2[2*k+1];
                identifier_l3[k] = right_l3[k]
                    ? identifier_l2[2*k+1] : identifier_l2[2*k];
            end

            for (k = 0; k < 2; k = k + 1) begin
                valid_l4[k] = valid_l3[2*k] | valid_l3[2*k+1];
                right_l4[k] = (valid_l3[2*k] && valid_l3[2*k+1])
                    ? ~random_bits[28+k] : valid_l3[2*k+1];
                identifier_l4[k] = right_l4[k]
                    ? identifier_l3[2*k+1] : identifier_l3[2*k];
            end

            valid_l5 = valid_l4[0] | valid_l4[1];
            right_l5 = (valid_l4[0] && valid_l4[1])
                ? ~random_bits[30] : valid_l4[1];
            identifier_l5 = right_l5
                ? identifier_l4[1] : identifier_l4[0];

            // Reconstruct the path from its five Boolean branch decisions.
            selected_index[4] = right_l5;
            selected_index[3] = right_l4[selected_index[4]];
            selected_index[2] = right_l3[selected_index[4:3]];
            selected_index[1] = right_l2[selected_index[4:2]];
            selected_index[0] = right_l1[selected_index[4:1]];

            select_32_path = {valid_l5, identifier_l5, selected_index};
        end
    endfunction

    reg [31:0] row_valid_comb;
    reg [31:0] row_identifier_comb;
    reg [4:0]  row_column_comb [0:31];
    integer row_i;

    // First five levels: 32 independent 32-bit row selectors.
    always @(*) begin
        for (row_i = 0; row_i < 32; row_i = row_i + 1) begin
            {row_valid_comb[row_i], row_identifier_comb[row_i],
             row_column_comb[row_i]} = select_32_path(
                valid_bits[row_i*32 +: 32],
                identifier_bits[row_i*32 +: 32],
                {
                    rand_bits[960+row_i],
                    rand_bits[896+row_i*2 +: 2],
                    rand_bits[768+row_i*4 +: 4],
                    rand_bits[512+row_i*8 +: 8],
                    rand_bits[row_i*16 +: 16]
                }
            );
        end
    end

    // The only synchronization boundary, in the same place as the old tree:
    // after five levels and immediately before the final 32-input selector.
    reg [31:0] row_valid_pipe;
    reg [31:0] row_identifier_pipe;
    reg [4:0]  row_column_pipe [0:31];
    integer pipe_i;

    always @(posedge clk) begin
        if (rst) begin
            row_valid_pipe <= 32'd0;
            row_identifier_pipe <= 32'd0;
            for (pipe_i = 0; pipe_i < 32; pipe_i = pipe_i + 1)
                row_column_pipe[pipe_i] <= 5'd0;
        end else begin
            row_valid_pipe <= row_valid_comb;
            row_identifier_pipe <= row_identifier_comb;
            for (pipe_i = 0; pipe_i < 32; pipe_i = pipe_i + 1)
                row_column_pipe[pipe_i] <= row_column_comb[pipe_i];
        end
    end

    // Final five levels. The validity/right-path tree constructs the upper
    // five row bits. The five-bit column payload follows those same choices
    // at each level, avoiding a late 32-to-1 mux after row selection.
    reg [15:0] top_valid_l1;
    reg [15:0] top_right_l1;
    reg [4:0]  column_l1 [0:15];
    reg [15:0] identifier_l1;
    reg [7:0]  top_valid_l2;
    reg [7:0]  top_right_l2;
    reg [4:0]  column_l2 [0:7];
    reg [7:0]  identifier_l2;
    reg [3:0]  top_valid_l3;
    reg [3:0]  top_right_l3;
    reg [4:0]  column_l3 [0:3];
    reg [3:0]  identifier_l3;
    reg [1:0]  top_valid_l4;
    reg [1:0]  top_right_l4;
    reg [4:0]  column_l4 [0:1];
    reg [1:0]  identifier_l4;
    reg        top_valid_l5;
    reg        top_right_l5;
    reg [4:0]  column_l5;
    reg        identifier_l5;
    reg [4:0]  selected_row;
    reg [9:0]  final_index_comb;
    reg        final_valid_comb;
    reg        final_identifier_comb;
    integer top_i;

    always @(*) begin
        for (top_i = 0; top_i < 16; top_i = top_i + 1) begin
            top_valid_l1[top_i] =
                row_valid_pipe[2*top_i] | row_valid_pipe[2*top_i+1];
            top_right_l1[top_i] =
                (row_valid_pipe[2*top_i] && row_valid_pipe[2*top_i+1])
                    ? ~rand_bits[992+top_i] : row_valid_pipe[2*top_i+1];
            column_l1[top_i] = top_right_l1[top_i]
                ? row_column_pipe[2*top_i+1] : row_column_pipe[2*top_i];
            identifier_l1[top_i] = top_right_l1[top_i]
                ? row_identifier_pipe[2*top_i+1]
                : row_identifier_pipe[2*top_i];
        end

        for (top_i = 0; top_i < 8; top_i = top_i + 1) begin
            top_valid_l2[top_i] =
                top_valid_l1[2*top_i] | top_valid_l1[2*top_i+1];
            top_right_l2[top_i] =
                (top_valid_l1[2*top_i] && top_valid_l1[2*top_i+1])
                    ? ~rand_bits[1008+top_i] : top_valid_l1[2*top_i+1];
            column_l2[top_i] = top_right_l2[top_i]
                ? column_l1[2*top_i+1] : column_l1[2*top_i];
            identifier_l2[top_i] = top_right_l2[top_i]
                ? identifier_l1[2*top_i+1] : identifier_l1[2*top_i];
        end

        for (top_i = 0; top_i < 4; top_i = top_i + 1) begin
            top_valid_l3[top_i] =
                top_valid_l2[2*top_i] | top_valid_l2[2*top_i+1];
            top_right_l3[top_i] =
                (top_valid_l2[2*top_i] && top_valid_l2[2*top_i+1])
                    ? ~rand_bits[1016+top_i] : top_valid_l2[2*top_i+1];
            column_l3[top_i] = top_right_l3[top_i]
                ? column_l2[2*top_i+1] : column_l2[2*top_i];
            identifier_l3[top_i] = top_right_l3[top_i]
                ? identifier_l2[2*top_i+1] : identifier_l2[2*top_i];
        end

        for (top_i = 0; top_i < 2; top_i = top_i + 1) begin
            top_valid_l4[top_i] =
                top_valid_l3[2*top_i] | top_valid_l3[2*top_i+1];
            top_right_l4[top_i] =
                (top_valid_l3[2*top_i] && top_valid_l3[2*top_i+1])
                    ? ~rand_bits[1020+top_i] : top_valid_l3[2*top_i+1];
            column_l4[top_i] = top_right_l4[top_i]
                ? column_l3[2*top_i+1] : column_l3[2*top_i];
            identifier_l4[top_i] = top_right_l4[top_i]
                ? identifier_l3[2*top_i+1] : identifier_l3[2*top_i];
        end

        top_valid_l5 = top_valid_l4[0] | top_valid_l4[1];
        top_right_l5 = (top_valid_l4[0] && top_valid_l4[1])
            ? ~rand_bits[1022] : top_valid_l4[1];
        column_l5 = top_right_l5 ? column_l4[1] : column_l4[0];
        identifier_l5 = top_right_l5
            ? identifier_l4[1] : identifier_l4[0];

        selected_row[4] = top_right_l5;
        selected_row[3] = top_right_l4[selected_row[4]];
        selected_row[2] = top_right_l3[selected_row[4:3]];
        selected_row[1] = top_right_l2[selected_row[4:2]];
        selected_row[0] = top_right_l1[selected_row[4:1]];

        final_index_comb = {selected_row, column_l5};
        final_identifier_comb = identifier_l5;
        final_valid_comb = top_valid_l5;
    end

    assign final_index = final_index_comb;
    assign final_identifier = final_identifier_comb;
    assign final_valid = final_valid_comb;

endmodule
