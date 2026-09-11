// This example is for th case with 1024x1024 matrix, but it works for larger ones too
// Assume we are given the 10-bit row and column indices you want to address.
// The new compact memory is 1D array of 2^19=524,288 words, each 16 bits wide. Word size can be smaller if you want
module matrix_folding (
    input  wire [9:0] i,
    input  wire [9:0] j,
    output wire [18:0] address // 19 bits maps exactly to 524,288
);

    // 1. Enforce row > col (lower triangle)
    wire [9:0] r = (i > j) ? i : j;
    wire [9:0] c = (i > j) ? j : i;

    // 2. Check if we are in the Bottom-Right quadrant
    // This is true if both row and col are >= 512 (the 9th bit is '1')
    wire is_bottom_right = r[9] & c[9];

    // 3. Address Mapping (Pure Wiring)
    // If not Bottom-Right: Address is simply {r[9:0], c[8:0]}
    // If Bottom-Right: We fold it into the Top-Left empty space by stripping the 
    //        9th bit to bring it back to 0-511, and swapping row and col.
    //        This maps it to {1'b0, c[8:0], r[8:0]}
    
    assign address = is_bottom_right ? {1'b0, c[8:0], r[8:0]} 
                                     : {r[9:0], c[8:0]};

endmodule
