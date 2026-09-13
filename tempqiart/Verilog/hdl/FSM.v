module engine_control_fsm #(
    parameter WIDTH = 27,
    parameter ENGINE_COUNT = 2048,
    parameter INDEX_WIDTH = 11
)(
    input wire clk,
    input wire rst,
    
    // --- External Commands --- //
    input wire program,          // Trigger to loading initial values 1-cycle
    input wire Go,               // Trigger to start the optimization trials
    input wire [31:0] max_iter,  // Number of trials to run
    
    // --- Feedback from Datapath --- //
    input wire winner_found,     // From Tournament Tree (final_valid)

    // --- Execution Control Outputs --- //
    output reg rng_ADB_en,  
    output reg rng_US_en,
    output reg write_en,
    output reg ising_update_en,             
    output reg state_update_en,  
    output reg valid_hold_en,
    output reg e_off_update_en,  
    output reg h_update_en,
    output reg [ENGINE_COUNT-1:0] engine_load_en,
    output wire [INDEX_WIDTH-1:0] h_init_address,
    
    // --- Status Outputs --- //
    output reg busy,             // High during Programming OR Running
    output reg done,             // Pulses High when max_iter is reached

    output reg idle,
    output reg program_LED,
    output reg ready,
    output reg rg_gen,
    output reg sieve_wait,
    output reg sieve_wait2,
    output reg sieve_wait3,
    output reg update,
    output reg degloria
);

    // --- State Encoding --- //
    localparam S_IDLE        = 4'd0; // Wait for 'program'
    localparam S_PROGRAM     = 4'd9; // <-- NEW: used for programming local fields
    localparam S_READY       = 4'd2; // Programmed. Wait for 'Go'
    
    // --- The 5-Cycle Execution Loop --- //
    localparam S_RNG_GEN     = 4'd3; //Generatre random numbers for this trial
    localparam S_SIEVE_WAIT  = 4'd4; // DeltaE and ADBs to combinatorial logic
    localparam S_SIEVE_WAIT2 = 4'd5; // Extra wait state for update selector tree stabilization
    localparam S_SIEVE_WAIT3 = 4'd8; // Extra wait state for update selector tree stabilization
    localparam S_UPDATE      = 4'd6; // Update current state with winning bit flip
    localparam S_WEIGHT_WAIT = 4'd11; // Wait for weight RAM to stabilize since alsyncram updates output the next cycle
    localparam S_DEGLORIA    = 4'd7; // Update local H via DeGlria, check termination condition

    localparam S_STANDBY     = 4'd10; // DO NOT RESTART AFTER DONE ASSERTED
    // REPEAT

    reg [3:0] current_state, next_state;

    // --- Internal Iteration Counter --- //
    reg [31:0] iter_count;       // Counts trials up to max_iter

    // Two extra counts flush the address and output registers in the ROM.
    reg [INDEX_WIDTH:0] h_init_count;

    assign h_init_address = h_init_count[INDEX_WIDTH-1:0];

    // Go is only a 2-cycle pulse; if it arrives while still in S_PROGRAM it
    // must not be lost before the FSM reaches S_READY, so latch it here.
    reg go_pending;
    wire go_request = Go || go_pending;

    // --- Sequential Logic --- //
    always @(posedge clk) begin
        if (rst) begin
            current_state <= S_IDLE;
            iter_count    <= 32'd0;
            h_init_count  <= {(INDEX_WIDTH+1){1'b0}};
            go_pending    <= 1'b0;
        end else begin
            current_state <= next_state;

            // Iteration Counter Logic
            if (current_state == S_READY && go_request) begin
                iter_count <= 32'd0; // Reset before starting run
            end else if (current_state == S_DEGLORIA) begin
                iter_count <= iter_count + 1'b1;
            end

            // local field program counter logic
            if (current_state == S_IDLE) begin
                h_init_count <= {(INDEX_WIDTH+1){1'b0}};
            end else if (current_state == S_PROGRAM) begin
                h_init_count <= h_init_count + 1'b1;
            end

            // Go latch: set on any Go pulse, drop stale requests from a
            // previous run when (re)programming starts, clear once consumed.
            if (current_state == S_IDLE && program) begin
                go_pending <= 1'b0;
            end else if (current_state == S_READY && go_request) begin
                go_pending <= 1'b0;
            end else if (Go) begin
                go_pending <= 1'b1;
            end
        end
    end

    // --- Next State Logic --- //
    always @(*) begin
        next_state = current_state; // Default stay
        
        case (current_state)
            S_IDLE: begin
                if (program) next_state = S_PROGRAM;
            end

            S_PROGRAM: begin
              if (h_init_count >= ENGINE_COUNT + 1) next_state = S_READY;
            end
            
            S_READY: begin
                if (go_request) next_state = S_RNG_GEN;
            end
            
            // --- Execution Loop --- //
            S_RNG_GEN:     next_state = S_SIEVE_WAIT;
            S_SIEVE_WAIT:  next_state = S_SIEVE_WAIT2;
            S_SIEVE_WAIT2: next_state = S_SIEVE_WAIT3;
            S_SIEVE_WAIT3: next_state = S_UPDATE;
            S_UPDATE:      next_state = S_WEIGHT_WAIT;
            S_WEIGHT_WAIT: next_state = S_DEGLORIA;
            
            S_DEGLORIA: begin
                // Check termination condition
                if (iter_count >= max_iter - 1'b1) begin
                    next_state = S_IDLE; // Terminate and return to Idle -> waiting for program
                end else begin
                    next_state = S_RNG_GEN; // Loop to next trial
                end
            end

            S_STANDBY: begin
              next_state = S_STANDBY;
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    // --- Output Logic ---
    always @(*) begin
        // Default outputs
        rng_ADB_en      = 1'b0;
        rng_US_en       = 1'b0;
        state_update_en = 1'b0;
        valid_hold_en   = 1'b0;
        ising_update_en = 1'b0;
        e_off_update_en = 1'b0;
        h_update_en     = 1'b0;
        write_en        = 1'b0;
        busy            = 1'b0;
        done            = 1'b0;

        engine_load_en  = {ENGINE_COUNT{1'b0}};

        idle = 1'b0;
        program_LED = 1'b0;
        ready = 1'b0;
        rg_gen = 1'b0;
        sieve_wait = 1'b0;
        sieve_wait2 = 1'b0;
        sieve_wait3 = 1'b0;
        update  = 1'b0;
        degloria = 1'b0;

        case (current_state)
            S_IDLE: begin
                busy = 1'b0;
                idle = 1'b1;
            end

            S_PROGRAM: begin
                busy = 1'b0;
                program_LED = 1'b1;
                if ((h_init_count >= 2) && (h_init_count <= ENGINE_COUNT + 1)) begin
                    engine_load_en = {{(ENGINE_COUNT-1){1'b0}}, 1'b1}
                                     << (h_init_count - 2);
                end
            end

            S_READY: begin
                busy = 1'b0;
                ready = 1'b1;
                // Waiting for Go
            end

            S_RNG_GEN: begin
                busy   = 1'b1;
                rng_ADB_en = 1'b1; 
                rg_gen = 1'b1;
            end

            S_SIEVE_WAIT: begin
                busy = 1'b1;
                valid_hold_en = 1'b1;
                sieve_wait = 1'b1;
            end

            S_SIEVE_WAIT2: begin
                busy = 1'b1;
                rng_US_en = 1'b1;
                sieve_wait2 = 1'b1;
            end

            S_SIEVE_WAIT3: begin
                busy = 1'b1;
                sieve_wait3 = 1'b1;
            end

            S_UPDATE: begin
                busy         = 1'b1;
                e_off_update_en = 1'b1; // Update E_off -> Used in next trial
                if (winner_found) begin
                    state_update_en = 1'b1;
                    ising_update_en = 1'b1;
                end
                update = 1'b1;
            end

            S_WEIGHT_WAIT: begin
                busy = 1'b1;
                //sieve_wait3 = 1'b1;
            end

            S_DEGLORIA: begin
                busy = 1'b1;
                
                // Assert Done pulse on the very last cycle
                if (iter_count >= max_iter - 1'b1) begin
                    done = 1'b1;
                end

                // Local H Update Logic
                if (winner_found) begin
                    h_update_en     = 1'b1; // DeGloria's Algorithm
                    write_en        = 1'b1; // Enable writing updated X back to RAM
                end else begin
                end
                degloria = 1'b1;
            end

            S_STANDBY: begin
              done = 1'b1;
            end
        endcase
    end

endmodule
