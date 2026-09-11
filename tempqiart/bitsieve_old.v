
module BitSieve_256 (
    KEY, SW, CLOCK_50, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    address, writedata, write, read, byteenable, waitrequest, readdata, readdatavalid
);

    input [9:0] SW;
	input [3:0] KEY;
	input CLOCK_50;
	
    output [9:0] LEDR;
	output [6:0] HEX0;
  	output [6:0] HEX1;
	output [6:0] HEX2;
	output [6:0] HEX3;
	output [6:0] HEX4;
	output [6:0] HEX5;
    input  [24:0] address;
    input  [31:0] writedata;
    input         write;
    input         read;
    input  [3:0]  byteenable;
    output        waitrequest;
    output reg [31:0] readdata;
    output        readdatavalid;

	// --- Wires for Debug Signals --- //
	wire signed [27:0]  current_E_off;
	wire signed [31:0]  Ising_Energy;

    // --- Wires for Temp Signals --- //
	wire 			 busy_temp;
	wire 			 sign_temp;

    // --- Wires for External Control Signals --- //
    reg [1:0] sync_program_reg;
    reg [1:0] sync_Go_reg;

    wire rst;
    wire program;
    wire Go;

    // --- Wires for Control Signals to FSM --- //
    wire winner_found;

    // --- Wires for Control Signals from FSM --- //
    wire rng_ADB_en;
    wire rng_US_en;
    wire write_en;
    wire ising_update_en;
    wire state_update_en;
    wire valid_hold_en;
    wire e_off_update_en;
    wire h_update_en;
    wire programming_active;

    wire [2047:0] starting_state;
    wire [2047:0] engine_load_en;

    // --- Wires for the hyperparameter ROM connection --- //
    wire [31:0] hp_q_data;

    reg        [31:0]        max_iter_reg;
    // Address 3 of the hyperparameter ROM used to hold the synthesized-QUBO
    // penalty.  The general QUBO implementation no longer needs that value,
    // so retain the register name for compatibility and use bits [10:0] as the
    // programmable tabu-history depth (0 through 2047 entries).
    reg signed [31:0]        penalty_reg;
    reg signed [31:0]        init_ising_energy_reg;
    reg        [31:0]        random_seed_reg;
    reg signed [27:0]        e_off_delta_reg;
    // Exposed hierarchically to the ModelSim testbench for problem-specific
    // objective reconstruction and optimum detection.
    reg signed [31:0]        qubo_constant_raw_reg;
    reg signed [31:0]        global_min_raw_reg;
    reg        [11:0]        active_variable_count_reg;
    // Positive reference-Q25.2 units represented by one integer solver LSB.
    // This affects reporting only; the annealer datapath is entirely integer.
    reg        [31:0]        weight_scale_raw_q25_2_reg;

    // --- Wires for the init local fields ROM connection --- //
    wire	[10:0] h_init_address;
    wire	[27:0] h_init_value;

    // --- Wires for the SOLUTION RAM connection --- //
    reg  [9:0]   sol_write_addr;
    wire [2047:0] current_state_X;

    // --- Symmetric QUBO bank fabric --- //
    localparam integer ENGINE_COUNT    = 2048;
    localparam integer TWIN_COUNT      = 1024;
    localparam integer WEIGHT_WIDTH    = 10;
    localparam integer BANK_ROW_WIDTH  = TWIN_COUNT * WEIGHT_WIDTH;

    wire [10:0] winner_index;
    wire [(ENGINE_COUNT*WEIGHT_WIDTH)-1:0] qubo_weights;
    wire [BANK_ROW_WIDTH-1:0] bank_q_a_packed;
    wire [BANK_ROW_WIDTH-1:0] bank_q_b_packed;
    // TEMPORARILY DISABLED: these are only used by the large dynamic
    // bank-output unscrambler and create the bulk of the synthesis fanout.
    // wire [(2*BANK_ROW_WIDTH)-1:0] doubled_bank_q_a;
    // wire [(2*BANK_ROW_WIDTH)-1:0] doubled_bank_q_b;
    // wire [13:0] weight_barrel_shift_bits;
    reg  [9:0] sampled_weight_row_low;

    // =========================================================================
    // Avalon-MM Slave Interface to the symmetric matrix bank fabric
    // =========================================================================
    // The generated matrix-bank memory is organized as 1024 banks with 2048
    // entries each. The Avalon address is mapped as:
    //   [20:11] -> bank number (0..1023)
    //   [10:0]  -> row within that bank (0..2047)
    // This keeps the external CPU access narrow and readable while leaving the
    // engine-side dual-port bank access intact for the solver datapath.
    reg [9:0] avalon_last_bank_reg;
    reg [2:0] avalon_read_pipeline;

    wire [9:0]  avalon_bank          = address[20:11];
    wire [10:0] avalon_row           = address[10:0];
    wire        avalon_access_enable = (avalon_read_pipeline == 3'b000);
    wire        avalon_read_req      = read && avalon_access_enable;
    wire        avalon_write_req     = write && byteenable[0] && avalon_access_enable;

    assign waitrequest   = !avalon_access_enable;
    assign readdatavalid = avalon_read_pipeline[2];

    always @(posedge CLOCK_50) begin
        if (rst) begin
            avalon_last_bank_reg <= 10'd0;
            avalon_read_pipeline <= 3'b000;
            readdata             <= 32'd0;
        end else begin
            avalon_read_pipeline <= {
                avalon_read_pipeline[1:0],
                avalon_read_req
            };

            if (avalon_read_req) begin
                avalon_last_bank_reg <= avalon_bank;
            end

            if (avalon_read_pipeline[1]) begin
                readdata <= {22'd0,
                            bank_q_b_packed[(avalon_last_bank_reg * WEIGHT_WIDTH) +: WEIGHT_WIDTH]};
            end else if (avalon_write_req) begin
                readdata <= 32'd0;
            end
        end
    end

    // Build ../memoy/sym_mtrix_bank/sym_matrix_bank_DDDD.mif as a constant
    // string for each generated IP instance. The four decimal digits preserve
    // the reference IP's file naming convention through bank 1023.
    // function [8*48-1:0] sym_bank_init_file;
    //     input integer bank_number;
    //     reg [7:0] thousands;
    //     reg [7:0] hundreds;
    //     reg [7:0] tens;
    //     reg [7:0] ones;
    //     begin
    //         thousands = 8'd48 + ((bank_number / 1000) % 10);
    //         hundreds  = 8'd48 + ((bank_number / 100) % 10);
    //         tens      = 8'd48 + ((bank_number / 10) % 10);
    //         ones      = 8'd48 + (bank_number % 10);
    //         sym_bank_init_file = {
    //             "../memoy/sym_mtrix_bank/sym_matrix_bank_",
    //             thousands, hundreds, tens, ones, ".mif"
    //         };
    //     end
    // endfunction


    // =========================================================================
    // Asynchronous Input Synchronizers
    // =========================================================================

    // Use these clean, clock-aligned signals for the FSM instead of the raw inputs
    assign program = sync_program_reg[1];
    assign Go      = sync_Go_reg[1];

    reset_debouncer rst_filter (
        .clk(CLOCK_50),
        .async_rst_in(~KEY[0]), // Raw bouncing button
        .sync_rst_out(rst) // Clean, synchronized release
    );

    always @(posedge CLOCK_50) begin
        if (rst) begin
            sync_program_reg <= 2'b00;
            sync_Go_reg      <= 2'b00;
        end else begin
            sync_program_reg <= {sync_program_reg[0], SW[0]};
            sync_Go_reg      <= {sync_Go_reg[0], SW[1]};
        end
    end

    // =========================================================================
    // MEMORY: 1024 x (2048-word x 10-bit) symmetric dual-port banks
    // =========================================================================

    // For requested row i and physical bank b, the bank emits logical low
    // column (b-i_low) mod 1024 on Port A and its high-half partner on Port B.
    // max/min folding addresses the one stored representative of Q[i][j].
    genvar bank_id;
    generate
        for (bank_id = 0; bank_id < TWIN_COUNT; bank_id = bank_id + 1) begin : symmetric_qubo_banks
            // Port A remains available to the solver datapath. Avalon uses port B.
            wire bank_is_selected_by_avalon = (avalon_bank == bank_id) &&
                                              (avalon_read_req || avalon_write_req);

            sym_matrix_bank u_sym_matrix_bank (
                .address_a(11'd0),
                .address_b(bank_is_selected_by_avalon ? avalon_row : 11'd0),
                .clock(CLOCK_50),
                .data_a(10'd0),
                .data_b(bank_is_selected_by_avalon && avalon_write_req ? writedata[9:0] : 10'd0),
                .wren_a(1'b0),
                .wren_b(bank_is_selected_by_avalon && avalon_write_req),
                .q_a(bank_q_a_packed[(bank_id*WEIGHT_WIDTH) +: WEIGHT_WIDTH]),
                .q_b(bank_q_b_packed[(bank_id*WEIGHT_WIDTH) +: WEIGHT_WIDTH])
            );
        end
    endgenerate

    // TEMPORARILY DISABLED: dynamic weight remap section that creates the large
    // synthesis fanout. Keep this block commented out and restore it later by
    // uncommenting the original statements below.
    // always @(posedge CLOCK_50) begin
    //     if (rst)
    //         sampled_weight_row_low <= 10'd0;
    //     else
    //         sampled_weight_row_low <= winner_index[9:0];
    // end
    //
    // assign doubled_bank_q_a = {bank_q_a_packed, bank_q_a_packed};
    // assign doubled_bank_q_b = {bank_q_b_packed, bank_q_b_packed};
    // assign weight_barrel_shift_bits = sampled_weight_row_low * WEIGHT_WIDTH;
    // assign qubo_weights = {(ENGINE_COUNT*WEIGHT_WIDTH){1'b0}};
    //
    // assign qubo_weights[BANK_ROW_WIDTH-1:0] =
    //     doubled_bank_q_a >> weight_barrel_shift_bits;
    // assign qubo_weights[(2*BANK_ROW_WIDTH)-1:BANK_ROW_WIDTH] =
    //     doubled_bank_q_b >> weight_barrel_shift_bits;

    // Equivalent remap using one 10-bit selection per engine instead of two
    // full-width variable barrel shifts. The low and high halves preserve the
    // original A/B bank ordering and wrap at 1024 entries.
    always @(posedge CLOCK_50) begin
        if (rst)
            sampled_weight_row_low <= 10'd0;
        else
            sampled_weight_row_low <= winner_index[9:0];
    end

    genvar engine_id;
    generate
        for (engine_id = 0; engine_id < TWIN_COUNT; engine_id = engine_id + 1) begin : remapped_engine_weights
            wire [10:0] remap_bank_index;

            assign remap_bank_index = engine_id + sampled_weight_row_low;

            assign qubo_weights[(engine_id * WEIGHT_WIDTH) +: WEIGHT_WIDTH] =
                bank_q_a_packed[((remap_bank_index[9:0]) * WEIGHT_WIDTH) +: WEIGHT_WIDTH];

            assign qubo_weights[((engine_id + TWIN_COUNT) * WEIGHT_WIDTH) +: WEIGHT_WIDTH] =
                bank_q_b_packed[((remap_bank_index[9:0]) * WEIGHT_WIDTH) +: WEIGHT_WIDTH];
        end
    endgenerate

    // =========================================================================
    // ENGINE
    // =========================================================================

	bit_sieve_engine_25 #(
        .N(2048),
        .INDEX_WIDTH(11),
        .SELECTOR_WIDTH(2048),
        .FIELD_WIDTH(28),
        .ENERGY_WIDTH(32),
        .WEIGHT_WIDTH(10)
    ) uut (
        .clk(CLOCK_50),
        .rst(rst),

        .h_init_value(h_init_value),

        .rng_ADB_en(rng_ADB_en),
        .rng_US_en(rng_US_en),
        .ising_update_en(ising_update_en),
        .state_update_en(state_update_en),
        .valid_hold_en(valid_hold_en),
        .e_off_update_en(e_off_update_en),
        .h_update_en(h_update_en),
        .engine_load_en(engine_load_en),
        .packed_weights(qubo_weights),

        .tabu_depth(penalty_reg[10:0]),
        .active_variable_count(active_variable_count_reg),
        .init_ising_energy(init_ising_energy_reg),
        .random_seed(random_seed_reg),
        .e_off_delta(e_off_delta_reg),

        .winner_found_out(winner_found),
        .winner_index_out(winner_index),
        
        .starting_state(starting_state),
        .current_state_X(current_state_X),
        .Ising_Energy(Ising_Energy),
		.current_E_off(current_E_off)
    );

    // =========================================================================
    // Control Unit (FSM)
    // =========================================================================
    engine_control_fsm #(
        .WIDTH(28),
        .ENGINE_COUNT(2048),
        .INDEX_WIDTH(11)
    ) control_unit (
        .clk(CLOCK_50),
        .rst(rst),
        .program(program),
        .Go(Go),
        .max_iter(max_iter_reg),
        .winner_found(winner_found),
        
        // Outputs
        .rng_ADB_en(rng_ADB_en),
        .rng_US_en(rng_US_en),
        .write_en(write_en),
        .ising_update_en(ising_update_en),
        .state_update_en(state_update_en),
        .valid_hold_en(valid_hold_en),
        .e_off_update_en(e_off_update_en),
        .h_update_en(h_update_en),

        .engine_load_en(engine_load_en),
        .h_init_address(h_init_address),

        .busy(busy_temp),
        .done(LEDR[9]),

        .idle(LEDR[0]),
        .program_LED(programming_active),
		.ready(LEDR[2]),
		.rg_gen(LEDR[3]),
		.sieve_wait(LEDR[4]),
		.sieve_wait2(LEDR[5]),
		.sieve_wait3(LEDR[6]),
		.update(LEDR[7]),
		.degloria(LEDR[8])
    );

    assign LEDR[1] = programming_active;

    // =========================================================================
    // MEMORY: Hyperparameter Loading & Storage
    // =========================================================================

    // Instantiate the new ROM
    hyperparam_rom hp_rom (
        .address(h_init_address[4:0]), // 5-bit address for the 32-word ROM
        .clock(CLOCK_50),
        .q(hp_q_data)
    );

    // Piggyback on the 'is_programming' cycle to latch the 
    
    always @(posedge CLOCK_50) begin //NOTE: Can use negedge to avoid the 2-cycle delay, but keeping it simple for now

        if (rst) begin
            // Failsafe defaults in case ROM doesn't load
            max_iter_reg          <= 32'd0;
            penalty_reg           <= 32'd8;
            init_ising_energy_reg <= 32'sd0;
            random_seed_reg       <= 32'h12345678;
            e_off_delta_reg       <= 27'd2;
            qubo_constant_raw_reg <= 32'sd0;
            global_min_raw_reg    <= 32'sd0;
            active_variable_count_reg <= 12'd0;
            weight_scale_raw_q25_2_reg <= 32'd1;

        end else if (programming_active) begin
            // The generated ROM registers both its address and output, so
            // hp_q_data is two programming counts behind h_init_address.
            case (h_init_address)
                11'd2: max_iter_reg          <= hp_q_data;
                11'd3: penalty_reg           <= hp_q_data;       // Tabu depth is held in bits [10:0]
                11'd4: init_ising_energy_reg <= hp_q_data;
                11'd5: random_seed_reg       <= hp_q_data;
                11'd6: e_off_delta_reg       <= hp_q_data[27:0];
                // Registered ROM output is two h_init_address counts behind.
                11'd7: qubo_constant_raw_reg <= hp_q_data;
                11'd8: global_min_raw_reg    <= hp_q_data;
                11'd9: active_variable_count_reg <= hp_q_data[11:0];
                11'd10: weight_scale_raw_q25_2_reg <= hp_q_data;
            endcase
        end
    end

    // =========================================================================
    // MEMORY: Initial local fields
    // =========================================================================

    initial_h_rom	initial_h_rom_inst (
        .address (h_init_address),
        .clock (CLOCK_50),
        .q (h_init_value)
	);

    // =========================================================================
    // MEMORY: Solution Storage RAM
    // =========================================================================
	  
    always@(posedge CLOCK_50) begin
        if (rst) begin
          sol_write_addr <= 10'b0;
        end else if (write_en) begin
          sol_write_addr <= sol_write_addr + 1'b1;
        end
    end

//	state_ram	solution_ram_1024x2048_inst (
//		.address (sol_write_addr),
//		.clock (CLOCK_50),
//		.data (current_state_X),
//		.wren (write_en),
//		.q (starting_state)
//	);	

    // =========================================================================
    // OUTPUT HEX DISPLAY
    // =========================================================================
	

	
	//assign LEDR[9:1] = SW[9:1];

endmodule
module reset_debouncer (
    input wire clk,
    input wire async_rst_in,
    output reg sync_rst_out
);
    // 2-Stage synchronizer to prevent metastability
    reg [1:0] sync_reg;
    
    // 20-bit counter (Wait ~20ms at 50MHz to bypass all bouncing)
    reg [19:0] bounce_timer;

    always @(posedge clk) begin
        // Shift the asynchronous button signal into the clock domain
        sync_reg <= {sync_reg[0], async_rst_in};

        if (sync_reg[1] == 1'b1) begin
            // Button is actively pressed. Reset the timer and assert reset immediately.
            bounce_timer <= 20'd0;
            sync_rst_out <= 1'b1;
        end else begin
            // Button is released. Start counting.
            if (bounce_timer < 20'd10/*'hFFFFF*/) begin
                bounce_timer <= bounce_timer + 1'b1;
                sync_rst_out <= 1'b1; // Hold the reset high while we wait
            end else begin
                // Timer maxed out! The bounce is over. 
                // Release the reset cleanly and synchronously to all engines.
                sync_rst_out <= 1'b0; 
            end
        end
    end
endmodule
