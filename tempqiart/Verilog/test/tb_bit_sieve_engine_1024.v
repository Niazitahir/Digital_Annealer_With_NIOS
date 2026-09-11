`timescale 1ns / 1ps

module tb_bit_sieve_engine_1024;

    // =========================================================================
    // 1. Signals & Constants
    // =========================================================================
    reg clk;
    reg rst;
    
    // Control Inputs
    reg program;
    reg Go;
    reg [23:0] max_iter;
    
    // Outputs from DUT
    wire [1023:0] current_state_X;
    wire done;
    wire busy;
    wire [26:0] current_E_off;
    wire signed [26:0] Ising_Energy;

    // Simulation Control
    integer trial_count = 0;
    integer best_trial_count = -1;
    integer first_found_trial = -1;
    integer file_handle_energy;
    integer file_handle_flips;
    
    reg signed [26:0] best_ising_energy;
    reg signed [1024:0] best_current_state_X;


    // =========================================================
    // TSP Graph Parameters (32-City)
    // =========================================================
    integer adj_matrix [0:31][0:31];

    // min cost tour 32-city graph
    integer GLOBAL_MIN_COST = 152; 

    initial begin
        // Initialize Adjacency Matrix for 32 Cities
        // Diagonals set to 9999 to prevent zero-cost self-loops in evaluation.

        // From Node 0 to [0...31]
            adj_matrix[0 ][0 ] = 9999; adj_matrix[0 ][1 ] = 8   ; adj_matrix[0 ][2 ] = 4   ; adj_matrix[0 ][3 ] = 1   ; adj_matrix[0 ][4 ] = 2   ; adj_matrix[0 ][5 ] = 9   ; adj_matrix[0 ][6 ] = 6   ; adj_matrix[0 ][7 ] = 6   ; adj_matrix[0 ][8 ] = 12  ; adj_matrix[0 ][9 ] = 7   ; adj_matrix[0 ][10] = 2   ; adj_matrix[0 ][11] = 6   ; adj_matrix[0 ][12] = 9   ; adj_matrix[0 ][13] = 9   ; adj_matrix[0 ][14] = 7   ; adj_matrix[0 ][15] = 13  ; adj_matrix[0 ][16] = 6   ; adj_matrix[0 ][17] = 9   ; adj_matrix[0 ][18] = 7   ; adj_matrix[0 ][19] = 3   ; adj_matrix[0 ][20] = 9   ; adj_matrix[0 ][21] = 4   ; adj_matrix[0 ][22] = 9   ; adj_matrix[0 ][23] = 11  ; adj_matrix[0 ][24] = 12  ; adj_matrix[0 ][25] = 11  ; adj_matrix[0 ][26] = 12  ; adj_matrix[0 ][27] = 11  ; adj_matrix[0 ][28] = 12  ; adj_matrix[0 ][29] = 4   ; adj_matrix[0 ][30] = 16  ; adj_matrix[0 ][31] = 17  ;

        // From Node 1 to [0...31]
            adj_matrix[1 ][0 ] = 8   ; adj_matrix[1 ][1 ] = 9999; adj_matrix[1 ][2 ] = 7   ; adj_matrix[1 ][3 ] = 7   ; adj_matrix[1 ][4 ] = 8   ; adj_matrix[1 ][5 ] = 4   ; adj_matrix[1 ][6 ] = 6   ; adj_matrix[1 ][7 ] = 7   ; adj_matrix[1 ][8 ] = 14  ; adj_matrix[1 ][9 ] = 1   ; adj_matrix[1 ][10] = 6   ; adj_matrix[1 ][11] = 11  ; adj_matrix[1 ][12] = 8   ; adj_matrix[1 ][13] = 4   ; adj_matrix[1 ][14] = 8   ; adj_matrix[1 ][15] = 5   ; adj_matrix[1 ][16] = 13  ; adj_matrix[1 ][17] = 2   ; adj_matrix[1 ][18] = 15  ; adj_matrix[1 ][19] = 11  ; adj_matrix[1 ][20] = 16  ; adj_matrix[1 ][21] = 7   ; adj_matrix[1 ][22] = 13  ; adj_matrix[1 ][23] = 12  ; adj_matrix[1 ][24] = 11  ; adj_matrix[1 ][25] = 19  ; adj_matrix[1 ][26] = 20  ; adj_matrix[1 ][27] = 17  ; adj_matrix[1 ][28] = 17  ; adj_matrix[1 ][29] = 11  ; adj_matrix[1 ][30] = 8   ; adj_matrix[1 ][31] = 25  ;

        // From Node 2 to [0...31]
            adj_matrix[2 ][0 ] = 4   ; adj_matrix[2 ][1 ] = 7   ; adj_matrix[2 ][2 ] = 9999; adj_matrix[2 ][3 ] = 3   ; adj_matrix[2 ][4 ] = 3   ; adj_matrix[2 ][5 ] = 10  ; adj_matrix[2 ][6 ] = 1   ; adj_matrix[2 ][7 ] = 9   ; adj_matrix[2 ][8 ] = 16  ; adj_matrix[2 ][9 ] = 5   ; adj_matrix[2 ][10] = 4   ; adj_matrix[2 ][11] = 10  ; adj_matrix[2 ][12] = 12  ; adj_matrix[2 ][13] = 5   ; adj_matrix[2 ][14] = 3   ; adj_matrix[2 ][15] = 10  ; adj_matrix[2 ][16] = 10  ; adj_matrix[2 ][17] = 6   ; adj_matrix[2 ][18] = 9   ; adj_matrix[2 ][19] = 7   ; adj_matrix[2 ][20] = 13  ; adj_matrix[2 ][21] = 7   ; adj_matrix[2 ][22] = 13  ; adj_matrix[2 ][23] = 7   ; adj_matrix[2 ][24] = 15  ; adj_matrix[2 ][25] = 13  ; adj_matrix[2 ][26] = 15  ; adj_matrix[2 ][27] = 10  ; adj_matrix[2 ][28] = 16  ; adj_matrix[2 ][29] = 5   ; adj_matrix[2 ][30] = 14  ; adj_matrix[2 ][31] = 19  ;

        // From Node 3 to [0...31]
            adj_matrix[3 ][0 ] = 1   ; adj_matrix[3 ][1 ] = 7   ; adj_matrix[3 ][2 ] = 3   ; adj_matrix[3 ][3 ] = 9999; adj_matrix[3 ][4 ] = 1   ; adj_matrix[3 ][5 ] = 9   ; adj_matrix[3 ][6 ] = 4   ; adj_matrix[3 ][7 ] = 7   ; adj_matrix[3 ][8 ] = 13  ; adj_matrix[3 ][9 ] = 6   ; adj_matrix[3 ][10] = 1   ; adj_matrix[3 ][11] = 7   ; adj_matrix[3 ][12] = 9   ; adj_matrix[3 ][13] = 7   ; adj_matrix[3 ][14] = 6   ; adj_matrix[3 ][15] = 11  ; adj_matrix[3 ][16] = 7   ; adj_matrix[3 ][17] = 7   ; adj_matrix[3 ][18] = 8   ; adj_matrix[3 ][19] = 4   ; adj_matrix[3 ][20] = 10  ; adj_matrix[3 ][21] = 4   ; adj_matrix[3 ][22] = 10  ; adj_matrix[3 ][23] = 10  ; adj_matrix[3 ][24] = 13  ; adj_matrix[3 ][25] = 12  ; adj_matrix[3 ][26] = 13  ; adj_matrix[3 ][27] = 11  ; adj_matrix[3 ][28] = 13  ; adj_matrix[3 ][29] = 4   ; adj_matrix[3 ][30] = 15  ; adj_matrix[3 ][31] = 18  ;

        // From Node 4 to [0...31]
            adj_matrix[4 ][0 ] = 2   ; adj_matrix[4 ][1 ] = 8   ; adj_matrix[4 ][2 ] = 3   ; adj_matrix[4 ][3 ] = 1   ; adj_matrix[4 ][4 ] = 9999; adj_matrix[4 ][5 ] = 10  ; adj_matrix[4 ][6 ] = 4   ; adj_matrix[4 ][7 ] = 8   ; adj_matrix[4 ][8 ] = 14  ; adj_matrix[4 ][9 ] = 7   ; adj_matrix[4 ][10] = 3   ; adj_matrix[4 ][11] = 8   ; adj_matrix[4 ][12] = 11  ; adj_matrix[4 ][13] = 8   ; adj_matrix[4 ][14] = 5   ; adj_matrix[4 ][15] = 12  ; adj_matrix[4 ][16] = 7   ; adj_matrix[4 ][17] = 8   ; adj_matrix[4 ][18] = 7   ; adj_matrix[4 ][19] = 4   ; adj_matrix[4 ][20] = 10  ; adj_matrix[4 ][21] = 5   ; adj_matrix[4 ][22] = 11  ; adj_matrix[4 ][23] = 9   ; adj_matrix[4 ][24] = 14  ; adj_matrix[4 ][25] = 11  ; adj_matrix[4 ][26] = 12  ; adj_matrix[4 ][27] = 10  ; adj_matrix[4 ][28] = 14  ; adj_matrix[4 ][29] = 3   ; adj_matrix[4 ][30] = 16  ; adj_matrix[4 ][31] = 17  ;

        // From Node 5 to [0...31]
            adj_matrix[5 ][0 ] = 9   ; adj_matrix[5 ][1 ] = 4   ; adj_matrix[5 ][2 ] = 10  ; adj_matrix[5 ][3 ] = 9   ; adj_matrix[5 ][4 ] = 10  ; adj_matrix[5 ][5 ] = 9999; adj_matrix[5 ][6 ] = 10  ; adj_matrix[5 ][7 ] = 5   ; adj_matrix[5 ][8 ] = 11  ; adj_matrix[5 ][9 ] = 5   ; adj_matrix[5 ][10] = 8   ; adj_matrix[5 ][11] = 10  ; adj_matrix[5 ][12] = 5   ; adj_matrix[5 ][13] = 8   ; adj_matrix[5 ][14] = 12  ; adj_matrix[5 ][15] = 8   ; adj_matrix[5 ][16] = 13  ; adj_matrix[5 ][17] = 6   ; adj_matrix[5 ][18] = 17  ; adj_matrix[5 ][19] = 12  ; adj_matrix[5 ][20] = 16  ; adj_matrix[5 ][21] = 7   ; adj_matrix[5 ][22] = 11  ; adj_matrix[5 ][23] = 16  ; adj_matrix[5 ][24] = 7   ; adj_matrix[5 ][25] = 21  ; adj_matrix[5 ][26] = 21  ; adj_matrix[5 ][27] = 20  ; adj_matrix[5 ][28] = 15  ; adj_matrix[5 ][29] = 13  ; adj_matrix[5 ][30] = 9   ; adj_matrix[5 ][31] = 26  ;

        // From Node 6 to [0...31]
            adj_matrix[6 ][0 ] = 6   ; adj_matrix[6 ][1 ] = 6   ; adj_matrix[6 ][2 ] = 1   ; adj_matrix[6 ][3 ] = 4   ; adj_matrix[6 ][4 ] = 4   ; adj_matrix[6 ][5 ] = 10  ; adj_matrix[6 ][6 ] = 9999; adj_matrix[6 ][7 ] = 10  ; adj_matrix[6 ][8 ] = 17  ; adj_matrix[6 ][9 ] = 5   ; adj_matrix[6 ][10] = 5   ; adj_matrix[6 ][11] = 12  ; adj_matrix[6 ][12] = 12  ; adj_matrix[6 ][13] = 4   ; adj_matrix[6 ][14] = 2   ; adj_matrix[6 ][15] = 9   ; adj_matrix[6 ][16] = 11  ; adj_matrix[6 ][17] = 5   ; adj_matrix[6 ][18] = 10  ; adj_matrix[6 ][19] = 8   ; adj_matrix[6 ][20] = 14  ; adj_matrix[6 ][21] = 8   ; adj_matrix[6 ][22] = 14  ; adj_matrix[6 ][23] = 6   ; adj_matrix[6 ][24] = 16  ; adj_matrix[6 ][25] = 14  ; adj_matrix[6 ][26] = 16  ; adj_matrix[6 ][27] = 11  ; adj_matrix[6 ][28] = 17  ; adj_matrix[6 ][29] = 7   ; adj_matrix[6 ][30] = 13  ; adj_matrix[6 ][31] = 20  ;

        // From Node 7 to [0...31]
            adj_matrix[7 ][0 ] = 6   ; adj_matrix[7 ][1 ] = 7   ; adj_matrix[7 ][2 ] = 9   ; adj_matrix[7 ][3 ] = 7   ; adj_matrix[7 ][4 ] = 8   ; adj_matrix[7 ][5 ] = 5   ; adj_matrix[7 ][6 ] = 10  ; adj_matrix[7 ][7 ] = 9999; adj_matrix[7 ][8 ] = 7   ; adj_matrix[7 ][9 ] = 8   ; adj_matrix[7 ][10] = 5   ; adj_matrix[7 ][11] = 5   ; adj_matrix[7 ][12] = 3   ; adj_matrix[7 ][13] = 10  ; adj_matrix[7 ][14] = 12  ; adj_matrix[7 ][15] = 12  ; adj_matrix[7 ][16] = 8   ; adj_matrix[7 ][17] = 9   ; adj_matrix[7 ][18] = 13  ; adj_matrix[7 ][19] = 8   ; adj_matrix[7 ][20] = 11  ; adj_matrix[7 ][21] = 3   ; adj_matrix[7 ][22] = 6   ; adj_matrix[7 ][23] = 16  ; adj_matrix[7 ][24] = 6   ; adj_matrix[7 ][25] = 17  ; adj_matrix[7 ][26] = 17  ; adj_matrix[7 ][27] = 18  ; adj_matrix[7 ][28] = 10  ; adj_matrix[7 ][29] = 10  ; adj_matrix[7 ][30] = 14  ; adj_matrix[7 ][31] = 22  ;

        // From Node 8 to [0...31]
            adj_matrix[8 ][0 ] = 12  ; adj_matrix[8 ][1 ] = 14  ; adj_matrix[8 ][2 ] = 16  ; adj_matrix[8 ][3 ] = 13  ; adj_matrix[8 ][4 ] = 14  ; adj_matrix[8 ][5 ] = 11  ; adj_matrix[8 ][6 ] = 17  ; adj_matrix[8 ][7 ] = 7   ; adj_matrix[8 ][8 ] = 9999; adj_matrix[8 ][9 ] = 15  ; adj_matrix[8 ][10] = 12  ; adj_matrix[8 ][11] = 7   ; adj_matrix[8 ][12] = 6   ; adj_matrix[8 ][13] = 17  ; adj_matrix[8 ][14] = 19  ; adj_matrix[8 ][15] = 18  ; adj_matrix[8 ][16] = 11  ; adj_matrix[8 ][17] = 16  ; adj_matrix[8 ][18] = 17  ; adj_matrix[8 ][19] = 13  ; adj_matrix[8 ][20] = 12  ; adj_matrix[8 ][21] = 9   ; adj_matrix[8 ][22] = 4   ; adj_matrix[8 ][23] = 23  ; adj_matrix[8 ][24] = 4   ; adj_matrix[8 ][25] = 21  ; adj_matrix[8 ][26] = 19  ; adj_matrix[8 ][27] = 23  ; adj_matrix[8 ][28] = 7   ; adj_matrix[8 ][29] = 15  ; adj_matrix[8 ][30] = 20  ; adj_matrix[8 ][31] = 24  ;

        // From Node 9 to [0...31]
            adj_matrix[9 ][0 ] = 7   ; adj_matrix[9 ][1 ] = 1   ; adj_matrix[9 ][2 ] = 5   ; adj_matrix[9 ][3 ] = 6   ; adj_matrix[9 ][4 ] = 7   ; adj_matrix[9 ][5 ] = 5   ; adj_matrix[9 ][6 ] = 5   ; adj_matrix[9 ][7 ] = 8   ; adj_matrix[9 ][8 ] = 15  ; adj_matrix[9 ][9 ] = 9999; adj_matrix[9 ][10] = 5   ; adj_matrix[9 ][11] = 11  ; adj_matrix[9 ][12] = 9   ; adj_matrix[9 ][13] = 3   ; adj_matrix[9 ][14] = 7   ; adj_matrix[9 ][15] = 5   ; adj_matrix[9 ][16] = 13  ; adj_matrix[9 ][17] = 1   ; adj_matrix[9 ][18] = 14  ; adj_matrix[9 ][19] = 10  ; adj_matrix[9 ][20] = 16  ; adj_matrix[9 ][21] = 7   ; adj_matrix[9 ][22] = 13  ; adj_matrix[9 ][23] = 11  ; adj_matrix[9 ][24] = 12  ; adj_matrix[9 ][25] = 18  ; adj_matrix[9 ][26] = 19  ; adj_matrix[9 ][27] = 16  ; adj_matrix[9 ][28] = 17  ; adj_matrix[9 ][29] = 10  ; adj_matrix[9 ][30] = 9   ; adj_matrix[9 ][31] = 24  ;

        // From Node 10 to [0...31]
            adj_matrix[10][0 ] = 2   ; adj_matrix[10][1 ] = 6   ; adj_matrix[10][2 ] = 4   ; adj_matrix[10][3 ] = 1   ; adj_matrix[10][4 ] = 3   ; adj_matrix[10][5 ] = 8   ; adj_matrix[10][6 ] = 5   ; adj_matrix[10][7 ] = 5   ; adj_matrix[10][8 ] = 12  ; adj_matrix[10][9 ] = 5   ; adj_matrix[10][10] = 9999; adj_matrix[10][11] = 7   ; adj_matrix[10][12] = 8   ; adj_matrix[10][13] = 7   ; adj_matrix[10][14] = 7   ; adj_matrix[10][15] = 11  ; adj_matrix[10][16] = 7   ; adj_matrix[10][17] = 7   ; adj_matrix[10][18] = 9   ; adj_matrix[10][19] = 5   ; adj_matrix[10][20] = 10  ; adj_matrix[10][21] = 3   ; adj_matrix[10][22] = 9   ; adj_matrix[10][23] = 11  ; adj_matrix[10][24] = 11  ; adj_matrix[10][25] = 13  ; adj_matrix[10][26] = 14  ; adj_matrix[10][27] = 13  ; adj_matrix[10][28] = 13  ; adj_matrix[10][29] = 5   ; adj_matrix[10][30] = 14  ; adj_matrix[10][31] = 19  ;

        // From Node 11 to [0...31]
            adj_matrix[11][0 ] = 6   ; adj_matrix[11][1 ] = 11  ; adj_matrix[11][2 ] = 10  ; adj_matrix[11][3 ] = 7   ; adj_matrix[11][4 ] = 8   ; adj_matrix[11][5 ] = 10  ; adj_matrix[11][6 ] = 12  ; adj_matrix[11][7 ] = 5   ; adj_matrix[11][8 ] = 7   ; adj_matrix[11][9 ] = 11  ; adj_matrix[11][10] = 7   ; adj_matrix[11][11] = 9999; adj_matrix[11][12] = 7   ; adj_matrix[11][13] = 14  ; adj_matrix[11][14] = 13  ; adj_matrix[11][15] = 16  ; adj_matrix[11][16] = 4   ; adj_matrix[11][17] = 13  ; adj_matrix[11][18] = 10  ; adj_matrix[11][19] = 5   ; adj_matrix[11][20] = 6   ; adj_matrix[11][21] = 4   ; adj_matrix[11][22] = 3   ; adj_matrix[11][23] = 17  ; adj_matrix[11][24] = 9   ; adj_matrix[11][25] = 13  ; adj_matrix[11][26] = 13  ; adj_matrix[11][27] = 16  ; adj_matrix[11][28] = 6   ; adj_matrix[11][29] = 8   ; adj_matrix[11][30] = 19  ; adj_matrix[11][31] = 17  ;

        // From Node 12 to [0...31]
            adj_matrix[12][0 ] = 9   ; adj_matrix[12][1 ] = 8   ; adj_matrix[12][2 ] = 12  ; adj_matrix[12][3 ] = 9   ; adj_matrix[12][4 ] = 11  ; adj_matrix[12][5 ] = 5   ; adj_matrix[12][6 ] = 12  ; adj_matrix[12][7 ] = 3   ; adj_matrix[12][8 ] = 6   ; adj_matrix[12][9 ] = 9   ; adj_matrix[12][10] = 8   ; adj_matrix[12][11] = 7   ; adj_matrix[12][12] = 9999; adj_matrix[12][13] = 12  ; adj_matrix[12][14] = 15  ; adj_matrix[12][15] = 13  ; adj_matrix[12][16] = 10  ; adj_matrix[12][17] = 10  ; adj_matrix[12][18] = 16  ; adj_matrix[12][19] = 11  ; adj_matrix[12][20] = 13  ; adj_matrix[12][21] = 6   ; adj_matrix[12][22] = 6   ; adj_matrix[12][23] = 19  ; adj_matrix[12][24] = 3   ; adj_matrix[12][25] = 20  ; adj_matrix[12][26] = 19  ; adj_matrix[12][27] = 21  ; adj_matrix[12][28] = 11  ; adj_matrix[12][29] = 13  ; adj_matrix[12][30] = 14  ; adj_matrix[12][31] = 24  ;

        // From Node 13 to [0...31]
            adj_matrix[13][0 ] = 9   ; adj_matrix[13][1 ] = 4   ; adj_matrix[13][2 ] = 5   ; adj_matrix[13][3 ] = 7   ; adj_matrix[13][4 ] = 8   ; adj_matrix[13][5 ] = 8   ; adj_matrix[13][6 ] = 4   ; adj_matrix[13][7 ] = 10  ; adj_matrix[13][8 ] = 17  ; adj_matrix[13][9 ] = 3   ; adj_matrix[13][10] = 7   ; adj_matrix[13][11] = 14  ; adj_matrix[13][12] = 12  ; adj_matrix[13][13] = 9999; adj_matrix[13][14] = 5   ; adj_matrix[13][15] = 5   ; adj_matrix[13][16] = 14  ; adj_matrix[13][17] = 2   ; adj_matrix[13][18] = 14  ; adj_matrix[13][19] = 12  ; adj_matrix[13][20] = 17  ; adj_matrix[13][21] = 9   ; adj_matrix[13][22] = 16  ; adj_matrix[13][23] = 8   ; adj_matrix[13][24] = 15  ; adj_matrix[13][25] = 18  ; adj_matrix[13][26] = 20  ; adj_matrix[13][27] = 15  ; adj_matrix[13][28] = 19  ; adj_matrix[13][29] = 10  ; adj_matrix[13][30] = 9   ; adj_matrix[13][31] = 24  ;

        // From Node 14 to [0...31]
            adj_matrix[14][0 ] = 7   ; adj_matrix[14][1 ] = 8   ; adj_matrix[14][2 ] = 3   ; adj_matrix[14][3 ] = 6   ; adj_matrix[14][4 ] = 5   ; adj_matrix[14][5 ] = 12  ; adj_matrix[14][6 ] = 2   ; adj_matrix[14][7 ] = 12  ; adj_matrix[14][8 ] = 19  ; adj_matrix[14][9 ] = 7   ; adj_matrix[14][10] = 7   ; adj_matrix[14][11] = 13  ; adj_matrix[14][12] = 15  ; adj_matrix[14][13] = 5   ; adj_matrix[14][14] = 9999; adj_matrix[14][15] = 10  ; adj_matrix[14][16] = 13  ; adj_matrix[14][17] = 7   ; adj_matrix[14][18] = 10  ; adj_matrix[14][19] = 9   ; adj_matrix[14][20] = 15  ; adj_matrix[14][21] = 10  ; adj_matrix[14][22] = 16  ; adj_matrix[14][23] = 4   ; adj_matrix[14][24] = 18  ; adj_matrix[14][25] = 14  ; adj_matrix[14][26] = 16  ; adj_matrix[14][27] = 9   ; adj_matrix[14][28] = 19  ; adj_matrix[14][29] = 7   ; adj_matrix[14][30] = 15  ; adj_matrix[14][31] = 20  ;

        // From Node 15 to [0...31]
            adj_matrix[15][0 ] = 13  ; adj_matrix[15][1 ] = 5   ; adj_matrix[15][2 ] = 10  ; adj_matrix[15][3 ] = 11  ; adj_matrix[15][4 ] = 12  ; adj_matrix[15][5 ] = 8   ; adj_matrix[15][6 ] = 9   ; adj_matrix[15][7 ] = 12  ; adj_matrix[15][8 ] = 18  ; adj_matrix[15][9 ] = 5   ; adj_matrix[15][10] = 11  ; adj_matrix[15][11] = 16  ; adj_matrix[15][12] = 13  ; adj_matrix[15][13] = 5   ; adj_matrix[15][14] = 10  ; adj_matrix[15][15] = 9999; adj_matrix[15][16] = 18  ; adj_matrix[15][17] = 4   ; adj_matrix[15][18] = 19  ; adj_matrix[15][19] = 16  ; adj_matrix[15][20] = 21  ; adj_matrix[15][21] = 12  ; adj_matrix[15][22] = 18  ; adj_matrix[15][23] = 13  ; adj_matrix[15][24] = 15  ; adj_matrix[15][25] = 23  ; adj_matrix[15][26] = 24  ; adj_matrix[15][27] = 20  ; adj_matrix[15][28] = 22  ; adj_matrix[15][29] = 15  ; adj_matrix[15][30] = 4   ; adj_matrix[15][31] = 29  ;

        // From Node 16 to [0...31]
            adj_matrix[16][0 ] = 6   ; adj_matrix[16][1 ] = 13  ; adj_matrix[16][2 ] = 10  ; adj_matrix[16][3 ] = 7   ; adj_matrix[16][4 ] = 7   ; adj_matrix[16][5 ] = 13  ; adj_matrix[16][6 ] = 11  ; adj_matrix[16][7 ] = 8   ; adj_matrix[16][8 ] = 11  ; adj_matrix[16][9 ] = 13  ; adj_matrix[16][10] = 7   ; adj_matrix[16][11] = 4   ; adj_matrix[16][12] = 10  ; adj_matrix[16][13] = 14  ; adj_matrix[16][14] = 13  ; adj_matrix[16][15] = 18  ; adj_matrix[16][16] = 9999; adj_matrix[16][17] = 14  ; adj_matrix[16][18] = 7   ; adj_matrix[16][19] = 3   ; adj_matrix[16][20] = 3   ; adj_matrix[16][21] = 6   ; adj_matrix[16][22] = 6   ; adj_matrix[16][23] = 16  ; adj_matrix[16][24] = 13  ; adj_matrix[16][25] = 10  ; adj_matrix[16][26] = 9   ; adj_matrix[16][27] = 13  ; adj_matrix[16][28] = 7   ; adj_matrix[16][29] = 6   ; adj_matrix[16][30] = 21  ; adj_matrix[16][31] = 14  ;

        // From Node 17 to [0...31]
            adj_matrix[17][0 ] = 9   ; adj_matrix[17][1 ] = 2   ; adj_matrix[17][2 ] = 6   ; adj_matrix[17][3 ] = 7   ; adj_matrix[17][4 ] = 8   ; adj_matrix[17][5 ] = 6   ; adj_matrix[17][6 ] = 5   ; adj_matrix[17][7 ] = 9   ; adj_matrix[17][8 ] = 16  ; adj_matrix[17][9 ] = 1   ; adj_matrix[17][10] = 7   ; adj_matrix[17][11] = 13  ; adj_matrix[17][12] = 10  ; adj_matrix[17][13] = 2   ; adj_matrix[17][14] = 7   ; adj_matrix[17][15] = 4   ; adj_matrix[17][16] = 14  ; adj_matrix[17][17] = 9999; adj_matrix[17][18] = 15  ; adj_matrix[17][19] = 12  ; adj_matrix[17][20] = 17  ; adj_matrix[17][21] = 8   ; adj_matrix[17][22] = 14  ; adj_matrix[17][23] = 11  ; adj_matrix[17][24] = 13  ; adj_matrix[17][25] = 19  ; adj_matrix[17][26] = 20  ; adj_matrix[17][27] = 16  ; adj_matrix[17][28] = 18  ; adj_matrix[17][29] = 11  ; adj_matrix[17][30] = 8   ; adj_matrix[17][31] = 25  ;

        // From Node 18 to [0...31]
            adj_matrix[18][0 ] = 7   ; adj_matrix[18][1 ] = 15  ; adj_matrix[18][2 ] = 9   ; adj_matrix[18][3 ] = 8   ; adj_matrix[18][4 ] = 7   ; adj_matrix[18][5 ] = 17  ; adj_matrix[18][6 ] = 10  ; adj_matrix[18][7 ] = 13  ; adj_matrix[18][8 ] = 17  ; adj_matrix[18][9 ] = 14  ; adj_matrix[18][10] = 9   ; adj_matrix[18][11] = 10  ; adj_matrix[18][12] = 16  ; adj_matrix[18][13] = 14  ; adj_matrix[18][14] = 10  ; adj_matrix[18][15] = 19  ; adj_matrix[18][16] = 7   ; adj_matrix[18][17] = 15  ; adj_matrix[18][18] = 9999; adj_matrix[18][19] = 5   ; adj_matrix[18][20] = 7   ; adj_matrix[18][21] = 10  ; adj_matrix[18][22] = 13  ; adj_matrix[18][23] = 12  ; adj_matrix[18][24] = 18  ; adj_matrix[18][25] = 4   ; adj_matrix[18][26] = 5   ; adj_matrix[18][27] = 7   ; adj_matrix[18][28] = 13  ; adj_matrix[18][29] = 4   ; adj_matrix[18][30] = 23  ; adj_matrix[18][31] = 10  ;

        // From Node 19 to [0...31]
            adj_matrix[19][0 ] = 3   ; adj_matrix[19][1 ] = 11  ; adj_matrix[19][2 ] = 7   ; adj_matrix[19][3 ] = 4   ; adj_matrix[19][4 ] = 4   ; adj_matrix[19][5 ] = 12  ; adj_matrix[19][6 ] = 8   ; adj_matrix[19][7 ] = 8   ; adj_matrix[19][8 ] = 13  ; adj_matrix[19][9 ] = 10  ; adj_matrix[19][10] = 5   ; adj_matrix[19][11] = 5   ; adj_matrix[19][12] = 11  ; adj_matrix[19][13] = 12  ; adj_matrix[19][14] = 9   ; adj_matrix[19][15] = 16  ; adj_matrix[19][16] = 3   ; adj_matrix[19][17] = 12  ; adj_matrix[19][18] = 5   ; adj_matrix[19][19] = 9999; adj_matrix[19][20] = 6   ; adj_matrix[19][21] = 5   ; adj_matrix[19][22] = 9   ; adj_matrix[19][23] = 13  ; adj_matrix[19][24] = 13  ; adj_matrix[19][25] = 9   ; adj_matrix[19][26] = 9   ; adj_matrix[19][27] = 11  ; adj_matrix[19][28] = 10  ; adj_matrix[19][29] = 3   ; adj_matrix[19][30] = 19  ; adj_matrix[19][31] = 14  ;

        // From Node 20 to [0...31]
            adj_matrix[20][0 ] = 9   ; adj_matrix[20][1 ] = 16  ; adj_matrix[20][2 ] = 13  ; adj_matrix[20][3 ] = 10  ; adj_matrix[20][4 ] = 10  ; adj_matrix[20][5 ] = 16  ; adj_matrix[20][6 ] = 14  ; adj_matrix[20][7 ] = 11  ; adj_matrix[20][8 ] = 12  ; adj_matrix[20][9 ] = 16  ; adj_matrix[20][10] = 10  ; adj_matrix[20][11] = 6   ; adj_matrix[20][12] = 13  ; adj_matrix[20][13] = 17  ; adj_matrix[20][14] = 15  ; adj_matrix[20][15] = 21  ; adj_matrix[20][16] = 3   ; adj_matrix[20][17] = 17  ; adj_matrix[20][18] = 7   ; adj_matrix[20][19] = 6   ; adj_matrix[20][20] = 9999; adj_matrix[20][21] = 9   ; adj_matrix[20][22] = 8   ; adj_matrix[20][23] = 18  ; adj_matrix[20][24] = 15  ; adj_matrix[20][25] = 9   ; adj_matrix[20][26] = 7   ; adj_matrix[20][27] = 14  ; adj_matrix[20][28] = 7   ; adj_matrix[20][29] = 8   ; adj_matrix[20][30] = 24  ; adj_matrix[20][31] = 12  ;

        // From Node 21 to [0...31]
            adj_matrix[21][0 ] = 4   ; adj_matrix[21][1 ] = 7   ; adj_matrix[21][2 ] = 7   ; adj_matrix[21][3 ] = 4   ; adj_matrix[21][4 ] = 5   ; adj_matrix[21][5 ] = 7   ; adj_matrix[21][6 ] = 8   ; adj_matrix[21][7 ] = 3   ; adj_matrix[21][8 ] = 9   ; adj_matrix[21][9 ] = 7   ; adj_matrix[21][10] = 3   ; adj_matrix[21][11] = 4   ; adj_matrix[21][12] = 6   ; adj_matrix[21][13] = 9   ; adj_matrix[21][14] = 10  ; adj_matrix[21][15] = 12  ; adj_matrix[21][16] = 6   ; adj_matrix[21][17] = 8   ; adj_matrix[21][18] = 10  ; adj_matrix[21][19] = 5   ; adj_matrix[21][20] = 9   ; adj_matrix[21][21] = 9999; adj_matrix[21][22] = 6   ; adj_matrix[21][23] = 14  ; adj_matrix[21][24] = 9   ; adj_matrix[21][25] = 14  ; adj_matrix[21][26] = 14  ; adj_matrix[21][27] = 15  ; adj_matrix[21][28] = 10  ; adj_matrix[21][29] = 7   ; adj_matrix[21][30] = 15  ; adj_matrix[21][31] = 19  ;

        // From Node 22 to [0...31]
            adj_matrix[22][0 ] = 9   ; adj_matrix[22][1 ] = 13  ; adj_matrix[22][2 ] = 13  ; adj_matrix[22][3 ] = 10  ; adj_matrix[22][4 ] = 11  ; adj_matrix[22][5 ] = 11  ; adj_matrix[22][6 ] = 14  ; adj_matrix[22][7 ] = 6   ; adj_matrix[22][8 ] = 4   ; adj_matrix[22][9 ] = 13  ; adj_matrix[22][10] = 9   ; adj_matrix[22][11] = 3   ; adj_matrix[22][12] = 6   ; adj_matrix[22][13] = 16  ; adj_matrix[22][14] = 16  ; adj_matrix[22][15] = 18  ; adj_matrix[22][16] = 6   ; adj_matrix[22][17] = 14  ; adj_matrix[22][18] = 13  ; adj_matrix[22][19] = 9   ; adj_matrix[22][20] = 8   ; adj_matrix[22][21] = 6   ; adj_matrix[22][22] = 9999; adj_matrix[22][23] = 20  ; adj_matrix[22][24] = 7   ; adj_matrix[22][25] = 16  ; adj_matrix[22][26] = 15  ; adj_matrix[22][27] = 19  ; adj_matrix[22][28] = 4   ; adj_matrix[22][29] = 11  ; adj_matrix[22][30] = 20  ; adj_matrix[22][31] = 20  ;

        // From Node 23 to [0...31]
            adj_matrix[23][0 ] = 11  ; adj_matrix[23][1 ] = 12  ; adj_matrix[23][2 ] = 7   ; adj_matrix[23][3 ] = 10  ; adj_matrix[23][4 ] = 9   ; adj_matrix[23][5 ] = 16  ; adj_matrix[23][6 ] = 6   ; adj_matrix[23][7 ] = 16  ; adj_matrix[23][8 ] = 23  ; adj_matrix[23][9 ] = 11  ; adj_matrix[23][10] = 11  ; adj_matrix[23][11] = 17  ; adj_matrix[23][12] = 19  ; adj_matrix[23][13] = 8   ; adj_matrix[23][14] = 4   ; adj_matrix[23][15] = 13  ; adj_matrix[23][16] = 16  ; adj_matrix[23][17] = 11  ; adj_matrix[23][18] = 12  ; adj_matrix[23][19] = 13  ; adj_matrix[23][20] = 18  ; adj_matrix[23][21] = 14  ; adj_matrix[23][22] = 20  ; adj_matrix[23][23] = 9999; adj_matrix[23][24] = 22  ; adj_matrix[23][25] = 14  ; adj_matrix[23][26] = 17  ; adj_matrix[23][27] = 8   ; adj_matrix[23][28] = 23  ; adj_matrix[23][29] = 10  ; adj_matrix[23][30] = 17  ; adj_matrix[23][31] = 21  ;

        // From Node 24 to [0...31]
            adj_matrix[24][0 ] = 12  ; adj_matrix[24][1 ] = 11  ; adj_matrix[24][2 ] = 15  ; adj_matrix[24][3 ] = 13  ; adj_matrix[24][4 ] = 14  ; adj_matrix[24][5 ] = 7   ; adj_matrix[24][6 ] = 16  ; adj_matrix[24][7 ] = 6   ; adj_matrix[24][8 ] = 4   ; adj_matrix[24][9 ] = 12  ; adj_matrix[24][10] = 11  ; adj_matrix[24][11] = 9   ; adj_matrix[24][12] = 3   ; adj_matrix[24][13] = 15  ; adj_matrix[24][14] = 18  ; adj_matrix[24][15] = 15  ; adj_matrix[24][16] = 13  ; adj_matrix[24][17] = 13  ; adj_matrix[24][18] = 18  ; adj_matrix[24][19] = 13  ; adj_matrix[24][20] = 15  ; adj_matrix[24][21] = 9   ; adj_matrix[24][22] = 7   ; adj_matrix[24][23] = 22  ; adj_matrix[24][24] = 9999; adj_matrix[24][25] = 22  ; adj_matrix[24][26] = 21  ; adj_matrix[24][27] = 24  ; adj_matrix[24][28] = 11  ; adj_matrix[24][29] = 16  ; adj_matrix[24][30] = 16  ; adj_matrix[24][31] = 26  ;

        // From Node 25 to [0...31]
            adj_matrix[25][0 ] = 11  ; adj_matrix[25][1 ] = 19  ; adj_matrix[25][2 ] = 13  ; adj_matrix[25][3 ] = 12  ; adj_matrix[25][4 ] = 11  ; adj_matrix[25][5 ] = 21  ; adj_matrix[25][6 ] = 14  ; adj_matrix[25][7 ] = 17  ; adj_matrix[25][8 ] = 21  ; adj_matrix[25][9 ] = 18  ; adj_matrix[25][10] = 13  ; adj_matrix[25][11] = 13  ; adj_matrix[25][12] = 20  ; adj_matrix[25][13] = 18  ; adj_matrix[25][14] = 14  ; adj_matrix[25][15] = 23  ; adj_matrix[25][16] = 10  ; adj_matrix[25][17] = 19  ; adj_matrix[25][18] = 4   ; adj_matrix[25][19] = 9   ; adj_matrix[25][20] = 9   ; adj_matrix[25][21] = 14  ; adj_matrix[25][22] = 16  ; adj_matrix[25][23] = 14  ; adj_matrix[25][24] = 22  ; adj_matrix[25][25] = 9999; adj_matrix[25][26] = 3   ; adj_matrix[25][27] = 7   ; adj_matrix[25][28] = 16  ; adj_matrix[25][29] = 8   ; adj_matrix[25][30] = 27  ; adj_matrix[25][31] = 6   ;

        // From Node 26 to [0...31]
            adj_matrix[26][0 ] = 12  ; adj_matrix[26][1 ] = 20  ; adj_matrix[26][2 ] = 15  ; adj_matrix[26][3 ] = 13  ; adj_matrix[26][4 ] = 12  ; adj_matrix[26][5 ] = 21  ; adj_matrix[26][6 ] = 16  ; adj_matrix[26][7 ] = 17  ; adj_matrix[26][8 ] = 19  ; adj_matrix[26][9 ] = 19  ; adj_matrix[26][10] = 14  ; adj_matrix[26][11] = 13  ; adj_matrix[26][12] = 19  ; adj_matrix[26][13] = 20  ; adj_matrix[26][14] = 16  ; adj_matrix[26][15] = 24  ; adj_matrix[26][16] = 9   ; adj_matrix[26][17] = 20  ; adj_matrix[26][18] = 5   ; adj_matrix[26][19] = 9   ; adj_matrix[26][20] = 7   ; adj_matrix[26][21] = 14  ; adj_matrix[26][22] = 15  ; adj_matrix[26][23] = 17  ; adj_matrix[26][24] = 21  ; adj_matrix[26][25] = 3   ; adj_matrix[26][26] = 9999; adj_matrix[26][27] = 10  ; adj_matrix[26][28] = 14  ; adj_matrix[26][29] = 9   ; adj_matrix[26][30] = 28  ; adj_matrix[26][31] = 5   ;

        // From Node 27 to [0...31]
            adj_matrix[27][0 ] = 11  ; adj_matrix[27][1 ] = 17  ; adj_matrix[27][2 ] = 10  ; adj_matrix[27][3 ] = 11  ; adj_matrix[27][4 ] = 10  ; adj_matrix[27][5 ] = 20  ; adj_matrix[27][6 ] = 11  ; adj_matrix[27][7 ] = 18  ; adj_matrix[27][8 ] = 23  ; adj_matrix[27][9 ] = 16  ; adj_matrix[27][10] = 13  ; adj_matrix[27][11] = 16  ; adj_matrix[27][12] = 21  ; adj_matrix[27][13] = 15  ; adj_matrix[27][14] = 9   ; adj_matrix[27][15] = 20  ; adj_matrix[27][16] = 13  ; adj_matrix[27][17] = 16  ; adj_matrix[27][18] = 7   ; adj_matrix[27][19] = 11  ; adj_matrix[27][20] = 14  ; adj_matrix[27][21] = 15  ; adj_matrix[27][22] = 19  ; adj_matrix[27][23] = 8   ; adj_matrix[27][24] = 24  ; adj_matrix[27][25] = 7   ; adj_matrix[27][26] = 10  ; adj_matrix[27][27] = 9999; adj_matrix[27][28] = 20  ; adj_matrix[27][29] = 8   ; adj_matrix[27][30] = 24  ; adj_matrix[27][31] = 13  ;

        // From Node 28 to [0...31]
            adj_matrix[28][0 ] = 12  ; adj_matrix[28][1 ] = 17  ; adj_matrix[28][2 ] = 16  ; adj_matrix[28][3 ] = 13  ; adj_matrix[28][4 ] = 14  ; adj_matrix[28][5 ] = 15  ; adj_matrix[28][6 ] = 17  ; adj_matrix[28][7 ] = 10  ; adj_matrix[28][8 ] = 7   ; adj_matrix[28][9 ] = 17  ; adj_matrix[28][10] = 13  ; adj_matrix[28][11] = 6   ; adj_matrix[28][12] = 11  ; adj_matrix[28][13] = 19  ; adj_matrix[28][14] = 19  ; adj_matrix[28][15] = 22  ; adj_matrix[28][16] = 7   ; adj_matrix[28][17] = 18  ; adj_matrix[28][18] = 13  ; adj_matrix[28][19] = 10  ; adj_matrix[28][20] = 7   ; adj_matrix[28][21] = 10  ; adj_matrix[28][22] = 4   ; adj_matrix[28][23] = 23  ; adj_matrix[28][24] = 11  ; adj_matrix[28][25] = 16  ; adj_matrix[28][26] = 14  ; adj_matrix[28][27] = 20  ; adj_matrix[28][28] = 9999; adj_matrix[28][29] = 13  ; adj_matrix[28][30] = 24  ; adj_matrix[28][31] = 18  ;

        // From Node 29 to [0...31]
            adj_matrix[29][0 ] = 4   ; adj_matrix[29][1 ] = 11  ; adj_matrix[29][2 ] = 5   ; adj_matrix[29][3 ] = 4   ; adj_matrix[29][4 ] = 3   ; adj_matrix[29][5 ] = 13  ; adj_matrix[29][6 ] = 7   ; adj_matrix[29][7 ] = 10  ; adj_matrix[29][8 ] = 15  ; adj_matrix[29][9 ] = 10  ; adj_matrix[29][10] = 5   ; adj_matrix[29][11] = 8   ; adj_matrix[29][12] = 13  ; adj_matrix[29][13] = 10  ; adj_matrix[29][14] = 7   ; adj_matrix[29][15] = 15  ; adj_matrix[29][16] = 6   ; adj_matrix[29][17] = 11  ; adj_matrix[29][18] = 4   ; adj_matrix[29][19] = 3   ; adj_matrix[29][20] = 8   ; adj_matrix[29][21] = 7   ; adj_matrix[29][22] = 11  ; adj_matrix[29][23] = 10  ; adj_matrix[29][24] = 16  ; adj_matrix[29][25] = 8   ; adj_matrix[29][26] = 9   ; adj_matrix[29][27] = 8   ; adj_matrix[29][28] = 13  ; adj_matrix[29][29] = 9999; adj_matrix[29][30] = 19  ; adj_matrix[29][31] = 14  ;

        // From Node 30 to [0...31]
            adj_matrix[30][0 ] = 16  ; adj_matrix[30][1 ] = 8   ; adj_matrix[30][2 ] = 14  ; adj_matrix[30][3 ] = 15  ; adj_matrix[30][4 ] = 16  ; adj_matrix[30][5 ] = 9   ; adj_matrix[30][6 ] = 13  ; adj_matrix[30][7 ] = 14  ; adj_matrix[30][8 ] = 20  ; adj_matrix[30][9 ] = 9   ; adj_matrix[30][10] = 14  ; adj_matrix[30][11] = 19  ; adj_matrix[30][12] = 14  ; adj_matrix[30][13] = 9   ; adj_matrix[30][14] = 15  ; adj_matrix[30][15] = 4   ; adj_matrix[30][16] = 21  ; adj_matrix[30][17] = 8   ; adj_matrix[30][18] = 23  ; adj_matrix[30][19] = 19  ; adj_matrix[30][20] = 24  ; adj_matrix[30][21] = 15  ; adj_matrix[30][22] = 20  ; adj_matrix[30][23] = 17  ; adj_matrix[30][24] = 16  ; adj_matrix[30][25] = 27  ; adj_matrix[30][26] = 28  ; adj_matrix[30][27] = 24  ; adj_matrix[30][28] = 24  ; adj_matrix[30][29] = 19  ; adj_matrix[30][30] = 9999; adj_matrix[30][31] = 33  ;

        // From Node 31 to [0...31]
            adj_matrix[31][0 ] = 17  ; adj_matrix[31][1 ] = 25  ; adj_matrix[31][2 ] = 19  ; adj_matrix[31][3 ] = 18  ; adj_matrix[31][4 ] = 17  ; adj_matrix[31][5 ] = 26  ; adj_matrix[31][6 ] = 20  ; adj_matrix[31][7 ] = 22  ; adj_matrix[31][8 ] = 24  ; adj_matrix[31][9 ] = 24  ; adj_matrix[31][10] = 19  ; adj_matrix[31][11] = 17  ; adj_matrix[31][12] = 24  ; adj_matrix[31][13] = 24  ; adj_matrix[31][14] = 20  ; adj_matrix[31][15] = 29  ; adj_matrix[31][16] = 14  ; adj_matrix[31][17] = 25  ; adj_matrix[31][18] = 10  ; adj_matrix[31][19] = 14  ; adj_matrix[31][20] = 12  ; adj_matrix[31][21] = 19  ; adj_matrix[31][22] = 20  ; adj_matrix[31][23] = 21  ; adj_matrix[31][24] = 26  ; adj_matrix[31][25] = 6   ; adj_matrix[31][26] = 5   ; adj_matrix[31][27] = 13  ; adj_matrix[31][28] = 18  ; adj_matrix[31][29] = 14  ; adj_matrix[31][30] = 33  ; adj_matrix[31][31] = 9999;
    end

    // =========================================================================
    // 2. Instantiate the Device Under Test (DUT)
    // =========================================================================
    bit_sieve_engine_25 #(
        .N(1024),
        .INDEX_WIDTH(10),
        .SELECTOR_WIDTH(1024),
        .MAX_ITER_WIDTH(24),
        .ISING_WIDTH(27),
        .WEIGHT_WIDTH(16)
    ) uut (
        .clk(clk),
        .rst(rst),
        .program(program),
        .Go(Go),
        .max_iter(max_iter),
        
        .current_state_X(current_state_X),
        .Ising_Energy(Ising_Energy),
        .done(done),
        .busy(busy),
        .current_E_off(current_E_off)
    );

    // =========================================================================
    // 3. Clock Generation (100 MHz -> 10ns period)
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // 4. Waveform Generation
    // =========================================================================
    initial begin
        // This creates a .vcd file you can open in GTKWave or ModelSim
        $dumpfile("simulation_dump.vcd");
        $dumpvars(0, tb_bit_sieve_engine_1024);
    end

    always @(uut.Ising_Energy) begin
      if (uut.Ising_Energy < best_ising_energy) begin
        best_ising_energy = uut.Ising_Energy;
        best_current_state_X = uut.current_state_X;
        best_trial_count = trial_count;
      end
    end

    // =========================================================================
    // 5. Stimulus Sequence
    // =========================================================================
    initial begin
        // --- A. Initialization ---
        rst = 1;
        program = 0;
        Go = 0;
        max_iter = 10; // Set a reasonable max iteration count for testing

        best_ising_energy = 27'h3FFFFFF;
        best_current_state_X = 256'b0;
        
        $display("----------------------------------------------------------------");
        $display("Starting Simulation: 32-City Bit Sieve Engine");
        $display("----------------------------------------------------------------");

        file_handle_energy = $fopen("output_log_energy.txt", "w");
        file_handle_flips = $fopen("output_log_flips.txt", "w");

        if (file_handle_energy == 0) begin
            $display("Error: Could not open file.");
            $finish;
        end

        if (file_handle_flips == 0) begin
            $display("Error: Could not open file.");
            $finish;
        end

        // --- B. Reset ---
        #20; 
        rst = 0;
        $display("[%0t ns] Reset released.", $time);
        
        // --- C. Program (Load Initial h_i) ---
        #10;
        program = 1;
        $display("[%0t ns] Programming Started (Loading h_i)...", $time);
        
        #10; // Pulse for 1 cycle (Simplified FSM handles instant load)
        program = 0;
        $display("[%0t ns] Programming Complete.", $time);

        // --- D. Start Execution ---
        #20;
        Go = 1;
        $display("[%0t ns] GO Signal Asserted. Running for %0d iterations...", $time, max_iter);
        
        // Hold Go for a cycle, then release (FSM should latch it or stay in Run)
        // Based on our FSM, Go triggers the transition. 
        // We can leave it High or pulse it. Let's leave it high to be safe.
        
        // --- E. Wait for Completion ---
        #30;
        Go = 0;
        $display("[%0t ns] GO Signal Released.", $time);
        wait(done);
        
        // Wait a few cycles to see the Done flag in waveforms
        #50;
        
        $display("----------------------------------------------------------------");
        $display("[%0t ns] Simulation Complete.", $time);
        $display("Final State X: %64b", current_state_X);
        $display("Best Ising Energy: %7d", best_ising_energy);
        $display("Best Trial Count: %0d", best_trial_count);
        check_and_print_tsp(best_current_state_X, best_trial_count);
        
        if (first_found_trial != -1) begin
            $display(">>> GLOBAL MINIMUM FIRST FOUND AT TRIAL: %0d <<<", first_found_trial);
        end
        $display("----------------------------------------------------------------");
        $finish;
    end

    // =========================================================================
    // 6. Logging (Print X on every trial)
    // =========================================================================
    // We monitor the internal FSM state to trigger the print exactly at the 
    // end of the Update phase (State 6 in our simplified FSM).
    // Note: Hierarchical reference 'uut.control_unit.current_state' depends on
    // your internal naming.
    
    always @(posedge clk) begin
        // Check if FSM is in S_UPDATE state (Value 6)
        if (uut.control_unit.current_state == 3'd6) begin
            trial_count = trial_count + 1;
            $fdisplay(file_handle_energy, "%7d", Ising_Energy);

            //if (uut.winner_found) begin
                $fdisplay(file_handle_flips, "%7d", uut.winner_index);
                $write("Trial %4d | X: %256h | Index: %3d | E_off: %5d | deltaE: %7d | Ising_Energy: %7d | ", 
                      trial_count, current_state_X, uut.winner_index, current_E_off, uut.delta_E_array[uut.winner_index], Ising_Energy);
                check_and_print_tsp(current_state_X, trial_count);
            //end
        end
    end

    // =========================================================
    // Task: Check for Legal TSP Tour (32-City)
    // =========================================================
    // Assuming 'state' is a 1024-bit register: reg [1023:0] state;
    // Grouping: 32 cities, 32 time steps per city.

    integer visit_order [0:31]; // Stores the city visited at each time step
    
    task check_and_print_tsp;
        input [1023:0] current_state;
        input integer current_trial;

        integer i, j;
        integer row_sum, col_sum;

        integer is_valid;

        begin
            is_valid = 1;
            
            // 1. Check Row Constraints (Each city visited exactly once)
            for (i = 0; i < 32; i = i + 1) begin
                row_sum = 0;
                for (j = 0; j < 32; j = j + 1) begin
                    // Indexing: city * 32 + time_step
                    row_sum = row_sum + current_state[i * 32 + j];
                    
                    // If the bit is 1, record the city (i) at this time step (j)
                    if (current_state[i * 32 + j] == 1'b1) begin
                        visit_order[j] = i; 
                    end
                end
                
                if (row_sum != 1) begin
                    is_valid = 0;
                end
            end
            
            // 2. Check Column Constraints (Only one city visited per time step)
            for (j = 0; j < 32; j = j + 1) begin
                col_sum = 0;
                for (i = 0; i < 32; i = i + 1) begin
                    col_sum = col_sum + current_state[i * 32 + j];
                end
                
                if (col_sum != 1) begin
                    is_valid = 0;
                end
            end
            
            // 3. Print the sequence if legal
            if (is_valid == 1) begin
                $write(" | TSP: ");
                for (j = 0; j < 32; j = j + 1) begin
                    // Adding 65 gives ASCII 'A' for City 0, 'B' for 1, etc.
                    // Note: ASCII alphabet only has 26 letters. 
                    // For 32 cities, we will just print the integer node IDs (0 to 31)
                    $write("%0d", visit_order[j]);
                    if (j < 31) $write("->");
                end
                // Pass the state to the cost evaluator to finish the line
                evaluate_and_print_cost(current_state, current_trial);

            end else begin
                $display(""); // Newline
            end
        end
    endtask

    // =========================================================
    // Task: Evaluate and Print Cost (32-City)
    // =========================================================
    task evaluate_and_print_cost;
        input [1023:0] current_state;
        input integer current_trial; 
        
        integer step;
        integer total_cost;
        integer current_city, next_city;
        begin
            total_cost = 0;
            
            // Note: We rely on the visit_order array populated by check_and_print_tsp.
            // Ensure check_and_print_tsp is called immediately before this task!
            
            // 1. Sum the sequential path distances
            for (step = 0; step < 31; step = step + 1) begin
                current_city = visit_order[step];
                next_city = visit_order[step + 1];
                
                total_cost = total_cost + adj_matrix[current_city][next_city];
            end
            
            // 2. Add the Hamiltonian wrap-around distance (Step 31 back to Step 0)
            current_city = visit_order[31];
            next_city = visit_order[0];
            total_cost = total_cost + adj_matrix[current_city][next_city];
            
            $write(" | Cost: %0d", total_cost);

            if (total_cost <= GLOBAL_MIN_COST) begin
                $display(" | SOLUTION FOUND!");
                
                // Record the trial number if this is the first time hitting the minimum
                if (first_found_trial == -1) begin
                    first_found_trial = current_trial;
                end
            end else begin
                $display(""); // Cap off the line
            end

        end
    endtask

endmodule