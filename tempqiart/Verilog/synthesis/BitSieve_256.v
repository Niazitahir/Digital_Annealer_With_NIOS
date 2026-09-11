
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
	wire signed [17:0]  current_E_off;
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
    // Only the low 18 bits of the loaded hyperparameter word are used,
    // matching the reduced FIELD_WIDTH.
    reg signed [17:0]        e_off_delta_reg;
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
    // The generated ROM is still 28 bits wide; only the low 18 bits are
    // used now that FIELD_WIDTH is reduced, so host-programmed values must
    // fit that signed range.
    wire	[27:0] h_init_value;

    // --- Wires for the SOLUTION RAM connection --- //
    reg  [9:0]   sol_write_addr;
    wire [2047:0] current_state_X;

    // --- Symmetric QUBO bank fabric --- //
    localparam integer ENGINE_COUNT    = 2048;
    localparam integer TWIN_COUNT      = 1024;
    localparam integer WEIGHT_WIDTH    = 10;
    localparam integer BANK_ROW_WIDTH  = TWIN_COUNT * WEIGHT_WIDTH;

    // The state RAM is used as a history/readback store. Keep solver startup
    // deterministic until a separate initialization policy is required.
    assign starting_state = {ENGINE_COUNT{1'b0}};

    wire [10:0] winner_index;
    wire [(ENGINE_COUNT*WEIGHT_WIDTH)-1:0] qubo_weights;
    wire [BANK_ROW_WIDTH-1:0] bank_q_a_packed;
    wire [BANK_ROW_WIDTH-1:0] bank_q_b_packed;
    reg  [9:0] sampled_weight_row_low;

    // =========================================================================
    // Avalon-MM Slave Interface to the symmetric matrix bank fabric
    // =========================================================================
    // Each of the 1024 banks stores both twin engines' folded rows directly:
    // port A holds the low engine's 1024-entry row, port B holds the high
    // engine's. The Avalon address is mapped as:
    //   [20:11] -> bank number (0..1023)
    //   [10]    -> engine half within the twin (0 = low/port A, 1 = high/port B)
    //   [9:0]   -> row within that engine's folded 1024-entry weight vector
    reg [9:0] avalon_last_bank_reg;
    reg       avalon_last_port_reg;
    reg [2:0] avalon_read_pipeline;
    reg [3:0] avalon_last_state_address_reg;
    reg [5:0] avalon_last_state_word_reg;
    reg       avalon_last_state_section_reg;
    reg [3:0] avalon_last_section_reg;

    wire [9:0]  avalon_bank          = address[20:11];
    wire [10:0] avalon_row           = address[10:0];
    wire        avalon_access_enable = (avalon_read_pipeline == 3'b000);
    wire        avalon_read_req      = read && avalon_access_enable;
    wire        avalon_write_req     = write && byteenable[0] && avalon_access_enable;
    wire        state_ram_read_active = !avalon_access_enable &&
                                        avalon_last_state_section_reg;
    wire [3:0]  state_ram_address = state_ram_read_active
        ? avalon_last_state_address_reg
        : sol_write_addr[3:0];
    wire        state_ram_wren = write_en && !state_ram_read_active;
    wire [2047:0] state_ram_q;

    assign waitrequest   = !avalon_access_enable;
    assign readdatavalid = avalon_read_pipeline[2];

    always @(posedge CLOCK_50) begin
        if (rst) begin
            avalon_last_bank_reg <= 10'd0;
            avalon_last_port_reg <= 1'b0;
            avalon_last_state_address_reg <= 4'd0;
            avalon_last_state_word_reg <= 6'd0;
            avalon_last_state_section_reg <= 1'b0;
            avalon_last_section_reg <= 4'd0;
            avalon_read_pipeline <= 3'b000;
            readdata             <= 32'd0;
        end else begin
            avalon_read_pipeline <= {
                avalon_read_pipeline[1:0],
                avalon_read_req
            };

            if (avalon_read_req) begin
                avalon_last_bank_reg <= avalon_bank;
                avalon_last_port_reg <= avalon_row[10];
                avalon_last_state_address_reg <= address[20:17];
                avalon_last_state_word_reg <= address[7:2];
                avalon_last_state_section_reg <= (address[24:21] == 4'b0010);
                avalon_last_section_reg <= address[24:21];
            end

            if (avalon_read_pipeline[1]) begin
                if (avalon_last_section_reg == 4'b0000) begin
                    readdata <= {22'd0,
                                avalon_last_port_reg
                                    ? bank_q_b_packed[(avalon_last_bank_reg * WEIGHT_WIDTH) +: WEIGHT_WIDTH]
                                    : bank_q_a_packed[(avalon_last_bank_reg * WEIGHT_WIDTH) +: WEIGHT_WIDTH]};
                end else if (avalon_last_state_section_reg) begin
                    readdata <= state_ram_q[
                        (avalon_last_state_word_reg * 32) +: 32];
                end
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
    // MEMORY: 1024 x (2048-word x 10-bit) folded twin-pair banks
    // =========================================================================

    // Diagonal symmetry folds each engine's weight vector to 1024 entries, so
    // one dual-port bank holds both twin engines' rows locally: port A is
    // engine bank_id's row, port B is engine (bank_id+TWIN_COUNT)'s row. Each
    // port is addressed directly by the shared sampled_weight_row_low value,
    // so no cross-bank remap/rotation is ever needed.

    // Single shared bank-select decoder: a 32x32 two-level tree instead of
    // 1024 independent 10-bit compares against the same avalon_bank value.
    wire avalon_access_active = avalon_read_req || avalon_write_req;
    wire [31:0] avalon_bank_hi_onehot;
    wire [31:0] avalon_bank_lo_onehot;
    wire [TWIN_COUNT-1:0] avalon_bank_onehot;
    genvar decode_hi, decode_lo;
    generate
        for (decode_hi = 0; decode_hi < 32; decode_hi = decode_hi + 1) begin : avalon_bank_hi_decode
            assign avalon_bank_hi_onehot[decode_hi] = (avalon_bank[9:5] == decode_hi);
        end
        for (decode_lo = 0; decode_lo < 32; decode_lo = decode_lo + 1) begin : avalon_bank_lo_decode
            assign avalon_bank_lo_onehot[decode_lo] = (avalon_bank[4:0] == decode_lo);
        end
    endgenerate

    genvar bank_id;
    generate
        for (bank_id = 0; bank_id < TWIN_COUNT; bank_id = bank_id + 1) begin : symmetric_qubo_banks
            assign avalon_bank_onehot[bank_id] =
                avalon_bank_hi_onehot[bank_id[9:5]] & avalon_bank_lo_onehot[bank_id[4:0]];

            wire bank_avalon_low_selected  = avalon_bank_onehot[bank_id] && !avalon_row[10] &&
                                              avalon_access_active;
            wire bank_avalon_high_selected = avalon_bank_onehot[bank_id] &&  avalon_row[10] &&
                                              avalon_access_active;

            // Port A/B are one shared 2048-word array: address MSB=0 selects
            // the low engine's half, MSB=1 the high engine's half, so both
            // ports always read disjoint, independent halves in parallel.
            sym_matrix_bank u_sym_matrix_bank (
                .address_a(bank_avalon_low_selected  ? {1'b0, avalon_row[9:0]} : {1'b0, sampled_weight_row_low}),
                .address_b(bank_avalon_high_selected ? {1'b1, avalon_row[9:0]} : {1'b1, sampled_weight_row_low}),
                .clock(CLOCK_50),
                .data_a(bank_avalon_low_selected  && avalon_write_req ? writedata[9:0] : 10'd0),
                .data_b(bank_avalon_high_selected && avalon_write_req ? writedata[9:0] : 10'd0),
                .wren_a(bank_avalon_low_selected  && avalon_write_req),
                .wren_b(bank_avalon_high_selected && avalon_write_req),
                .q_a(bank_q_a_packed[(bank_id*WEIGHT_WIDTH) +: WEIGHT_WIDTH]),
                .q_b(bank_q_b_packed[(bank_id*WEIGHT_WIDTH) +: WEIGHT_WIDTH])
            );
        end
    endgenerate

    always @(posedge CLOCK_50) begin
        if (rst)
            sampled_weight_row_low <= 10'd0;
        else
            sampled_weight_row_low <= winner_index[9:0];
    end

    // Each bank's data is already local to its own twin engines, so the
    // banks' direct outputs are the final per-engine weight vectors.
    assign qubo_weights[BANK_ROW_WIDTH-1:0]                  = bank_q_a_packed;
    assign qubo_weights[(2*BANK_ROW_WIDTH)-1:BANK_ROW_WIDTH] = bank_q_b_packed;

    // =========================================================================
    // ENGINE
    // =========================================================================

	bit_sieve_engine_25 #(
        .N(2048),
        .INDEX_WIDTH(11),
        .SELECTOR_WIDTH(2048),
        .FIELD_WIDTH(18),
        .ENERGY_WIDTH(32),
        .WEIGHT_WIDTH(10)
    ) uut (
        .clk(CLOCK_50),
        .rst(rst),

        .h_init_value(h_init_value[17:0]),

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
    hyperparam_ram hp_ram (
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
            e_off_delta_reg       <= 18'd2;
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
                11'd6: e_off_delta_reg       <= hp_q_data[17:0];
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

    initial_h_ram	initial_h_ram_inst (
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

    state_ram solution_state_ram (
        .address (state_ram_address),
        .clock   (CLOCK_50),
        .data    (current_state_X),
        .wren    (state_ram_wren),
        .q       (state_ram_q)
    );

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
