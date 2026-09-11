module lookup_table #(
    parameter N = 10,               // Address width (Default: 8 bits -> 256 entries)
    parameter DATA_WIDTH = 27,     // Data width (Fixed to 27 bits)
    parameter INIT_FILE = "../memoy/adb_lut.mem" // Relative to Verilog/simulation
)(
    input wire [N-1:0] addr,       // N-bit input address
    output wire [DATA_WIDTH-1:0] data_out // 27-bit output value
);

    // 1. Define the memory array
    // Depth is 2^N (1 << N)
    
    reg [31:0] rom_array [255:0];

    // 2. Initialize the LUT contents
    // A LUT is useless without data. We use $readmemh to load values 
    // from a generic text file during simulation or synthesis.

    initial begin
        $readmemh(INIT_FILE, rom_array);
    end

    // 3. Asynchronous Read Logic
    // The output updates immediately when 'addr' changes.
    assign data_out = rom_array[addr[9:2]][addr[1:0]];

endmodule
