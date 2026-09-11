module randomized_selector_2to1 #(parameter WIDTH=6) (
    input wire [WIDTH-1:0] indexA, indexB,
    input wire  vA, vB,
    input wire rand_bit,
    output wire [WIDTH-1:0] indexO,
    output wire vO
);
    assign vO = vA | vB;
    assign indexO = (vA && vB) ? (rand_bit ? indexA : indexB) :
                    (vA)       ? indexA :
                    (vB)       ? indexB : {WIDTH{1'b0}};
    // assign indexO = (vB) ? indexB :
    //                 (vA) ? indexA : {WIDTH{1'b0}};

endmodule