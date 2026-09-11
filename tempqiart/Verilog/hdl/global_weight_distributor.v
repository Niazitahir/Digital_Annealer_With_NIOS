module global_weight_distributor (

    input  wire [7:0]     j_idx,           // {city_j[4:0], time_j[4:0]}

    output reg  [255:0]   dist_fwd_flat,   // 8 x 16-bit: D[city][city_j]
    output reg  [255:0]   dist_rev_flat    // 8 x 16-bit: D[city_j][city]
);

    wire [3:0] city_j = j_idx[7:4];
    //wire [2:0] time_j = j_idx[2:0];

    reg signed [31:0] dist_flat [0:127];

    initial begin
        $readmemh("../memoy/tsp_adj.mem", dist_flat);
    end

    function automatic [15:0] get_dist;
        input integer src;
        input integer dst;
        integer word_idx;
        begin
            word_idx = (src * 8) + (dst >> 1);

            // Even destination column is in [15:0], odd is in [31:16]
            if ((dst & 1) == 0)
                get_dist = dist_flat[word_idx][15:0];
            else
                get_dist = dist_flat[word_idx][31:16];
        end
    endfunction

    integer c;
    always @* begin
        for (c = 0; c < 16; c = c + 1) begin
            dist_fwd_flat[(c*16) +: 16] = get_dist(c, city_j);
            dist_rev_flat[(c*16) +: 16] = get_dist(city_j, c);
        end
    end

    
endmodule

module global_weight_distributor_old (

    input  wire [7:0]     j_idx,           // {city_j[4:0], time_j[4:0]}

    output reg  [255:0]   dist_fwd_flat,   // 8 x 16-bit: D[city][city_j]
    output reg  [255:0]   dist_rev_flat    // 8 x 16-bit: D[city_j][city]
);

    wire [3:0] city_j = j_idx[7:4];
    //wire [2:0] time_j = j_idx[2:0];

    reg signed [4095:0] dist_flat [0:0];

    initial begin
        $readmemh("../memoy/tsp_adj.mem", dist_flat);
    end

    // Packed as row-major:
    // dist_flat[((src*8 + dst)*16) +: 16] = D[src][dst]
    function automatic [15:0] get_dist;
        input [4095:0] flat;
        input integer   src;
        input integer   dst;
        integer base;
        begin
            base = ((src * 16) + dst) * 16;
            get_dist = flat[base +: 16];
        end
    endfunction

    integer c;
    always @* begin
        for (c = 0; c < 16; c = c + 1) begin
            dist_fwd_flat[(c*16) +: 16] = get_dist(dist_flat[0], city_j, c);
            dist_rev_flat[(c*16) +: 16] = get_dist(dist_flat[0], c, city_j);
        end
    end

    
endmodule
