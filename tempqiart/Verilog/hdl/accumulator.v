module accumulator #(parameter WIDTH=27) (
    input wire clk,
    input wire rst,
    input wire en,
    input wire signed [WIDTH-1:0] D,
    output reg signed [WIDTH-1:0] Q
);
    always @(posedge clk) begin
        if (rst) Q <= 'd0;
        else if (en) Q <= Q + D;
    end
endmodule