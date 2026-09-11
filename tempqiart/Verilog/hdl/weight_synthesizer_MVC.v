module weight_synthesizer_MVC #(
    parameter NUM_VERTICES = 256,
    parameter INDEX_WIDTH  = 8,   // log2(NUM_VERTICES)
    parameter WEIGHT_WIDTH = 16   // 16-bit fixed-point signed binary
)(    
    // Broadcast from the Update Selector
    input  wire [INDEX_WIDTH-1:0]         j_index,   
    
    // Specific to Engine i (Configured via HPS/Avalon interface)
    input  wire [NUM_VERTICES-1:0]        adj_row,    
    input  wire signed [WEIGHT_WIDTH-1:0] penalty,  
    
    // Output to the Local Field Accumulator
    output reg  signed [WEIGHT_WIDTH-1:0] weight_out  
);

    // The adjacency check is a 256-to-1 multiplexer.
    // The output is registered to ensure the critical path from the 
    // update selector to the local field update remains short.
    always @(*) begin
        // If an edge exists between V_i and V_j, output -P. Otherwise, 0.
        if (adj_row[j_index]) begin
            weight_out <= penalty;
        end else begin
            weight_out <= {WEIGHT_WIDTH{1'b0}};
        end
    end

endmodule