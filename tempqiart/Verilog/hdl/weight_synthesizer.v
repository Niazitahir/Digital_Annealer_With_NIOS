module weight_synthesizer #(
    parameter IDX_ENGINE = 0, // Which city this engine corresponds to
    parameter WIDTH = 16
)(
    //input wire [127:0] row_weights, // The weights for this engine (W_i1, W_i2, ..., W_iN)

    input wire [WIDTH-1:0] dist_fwd_for_city_i,     // D[CITY_I][city_j]
    input wire [WIDTH-1:0] dist_rev_for_city_i,     // D[city_j][CITY_I]

    input wire [WIDTH-1:0] penalty, // The penalty value to use for constraint violations
    input wire [7:0] idx_j,
    // idx_j = 64 = 0b0100 0000 corresponds to CITY_4 at TIME_0

    output reg signed [WIDTH-1:0] weight
);

    localparam integer CITY_I = IDX_ENGINE[7:4];
    localparam integer TIME_I = IDX_ENGINE[3:0];

    localparam integer NEXT_TIME = (TIME_I == 15) ? 0 : (TIME_I + 1);
    localparam integer PREV_TIME = (TIME_I == 0) ? 15 : (TIME_I - 1);

    reg signed [WIDTH-1:0] constraint_term;
    reg signed [WIDTH-1:0] objective_term;

    wire [3:0] city_j = idx_j[7:4];
    wire [3:0] time_j = idx_j[3:0];

    always @* begin
      constraint_term = 16'sd0;
      objective_term  = 16'sd0;
      weight          = 16'sd0;

      if(idx_j == IDX_ENGINE) begin
        weight = 16'sd0; // No self-connection
      end else begin
        
        if ((city_j == CITY_I && time_j != TIME_I) || (time_j == TIME_I && city_j != CITY_I)) begin
          constraint_term = -penalty; // Violation of "One City Per Time Slot" or "One Time Slot Per City"
        end

        // Need to check both forward and reverse distances because incase TSP graph is directed.
        if (time_j == NEXT_TIME) begin
          objective_term = -$signed(dist_fwd_for_city_i);
        end

        if (time_j == PREV_TIME) begin
          objective_term = -$signed(dist_rev_for_city_i);
        end

        weight = objective_term + constraint_term;

      end
    end

endmodule