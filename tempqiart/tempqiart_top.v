module tempqiart_top #(
    parameter                           BUILD_REV = 48'h0
) (
  
    //FPGA Clock and Push Button Reset
    input  logic                        FPGA_CLK_IN     ,
    input  logic                        FPGA_PB_RESET_L ,
    
    //Reconfig
    output logic                        FPGA_RECONFIG   ,


    //Headers, LEDs, and Straps
    output logic                        FPGA_HB_LED     ,
    output logic    [15:0]              DBG_HEADER      ,
    output logic    [15:0]              STX_DBG_LED     ,
    input  logic    [15:0]              DBG_SWITCH      ,
    input  logic    [ 3:0]              STX_STRAP       ,
    //FMC Power
    output logic                        FMC_PWR_EN          ,
    output logic                        FMC_LA22_P          ,
    output logic                        FPGA_PG_C2M         ,
    
    //FPGA EXT Clock OUT
    output logic                        FPGA_EXT_CLK_OUT_P 
);

localparam                        HALF_SECOND   = 26'h5F5E0F;

//------------------------------------------------------------------------------
// Reset, clocks, and initialization 
//------------------------------------------------------------------------------

logic                             fpga_clk_100;               //100MHz clock from FPGA PLL
logic                             fpga_clk_sys_100;               //100MHz clock from FPGA PLL
logic                             fpga_clk_50;                //50MHz clock from FPGA PLL
logic                             fpga_clk_pll_lock;          //FPGA PLL lock
logic                             rst_sys;                    //System reset - synchronous to 100MHz clock
logic                             ptp_clk;
logic                             ptp_rst;
logic                             pb_rst_debounced;           //Debounced push button
//------------------------------------------------------------------------------
// Heartbeat and debug LEDs 
//------------------------------------------------------------------------------
logic                             heartbeat;                  //Heartbeat LED signal
logic   [25:0]                    second_cnt;                 //Counter for heartbeat LED logic
logic   [15:0]                    dbg_led_out;                //Debug LED output
logic   [9:0]                     sieve_ledr;
logic   [6:0]                     sieve_hex0;
logic   [6:0]                     sieve_hex1;
logic   [6:0]                     sieve_hex2;
logic   [6:0]                     sieve_hex3;
logic   [6:0]                     sieve_hex4;
logic   [6:0]                     sieve_hex5;
logic   [31:0]                    sieve_readdata;
logic                             sieve_readdatavalid;
logic   [24:0]                     qsys_avalon_address;
logic   [31:0]                     qsys_avalon_writedata;
logic                              qsys_avalon_write;
logic                              qsys_avalon_read;
logic   [3:0]                      qsys_avalon_byteenable;
logic                              sieve_waitrequest;
//------------------------------------------------------------------------------
// Heartbeat LED Logic
//------------------------------------------------------------------------------
rst_pb_debounce  rst_pb_debounce (
  .clk( FPGA_CLK_IN        ),
  .pb_rst_in                      ( FPGA_PB_RESET_L     ),
  .pb_rst_out                     ( pb_rst_debounced    )
);


fpga_clk_pll_mfg  fpga_clk_pll (                  
  .rst                            ( pb_rst_debounced    ),
  .refclk                         ( FPGA_CLK_IN         ),
  .locked                         ( fpga_clk_pll_lock   ),   
  .outclk_0                       ( fpga_clk_100        ),
  .outclk_1								 ( fpga_clk_50			  )
);


tempqiart u0 (
  .clk_clk         (fpga_clk_50),         //   input,  width = 1,       clk.clk
  .clock_out_clk   (fpga_clk_sys_100),   //  output,  width = 1, clock_out.clk
  .reset_out_reset (rst_sys),  //  output,  width = 1, reset_out.reset

  .avalon_qsys_waitrequest   (sieve_waitrequest),       //   input,   width = 1, avalon_qsys.waitrequest
  .avalon_qsys_readdata      (sieve_readdata),          //   input,  width = 32,            .readdata
  .avalon_qsys_readdatavalid (sieve_readdatavalid),      //   input,   width = 1,            .readdatavalid
  .avalon_qsys_burstcount    (),                        //  output,   width = 1,            .burstcount (unused, no consumer)
  .avalon_qsys_writedata     (qsys_avalon_writedata),   //  output,  width = 32,            .writedata
  .avalon_qsys_address       (qsys_avalon_address),     //  output,  width = 25,            .address (WORDS-addressed)
  .avalon_qsys_write         (qsys_avalon_write),       //  output,   width = 1,            .write
  .avalon_qsys_read          (qsys_avalon_read),        //  output,   width = 1,            .read
  .avalon_qsys_byteenable    (qsys_avalon_byteenable),  //  output,   width = 4,            .byteenable
  .avalon_qsys_debugaccess   ()                         //  output,   width = 1,            .debugaccess (unused, no consumer)
);


BitSieve_256 u1 (
.KEY        ({3'b111, ~rst_sys}),
.SW         (DBG_SWITCH[9:0]),
.CLOCK_50   (fpga_clk_sys_100),
.LEDR       (sieve_ledr),
.HEX0       (sieve_hex0),
.HEX1       (sieve_hex1),
.HEX2       (sieve_hex2),
.HEX3       (sieve_hex3),
.HEX4       (sieve_hex4),
.HEX5       (sieve_hex5),
.address    (qsys_avalon_address),
.writedata  (qsys_avalon_writedata),
.write      (qsys_avalon_write),
.read       (qsys_avalon_read),
.byteenable (qsys_avalon_byteenable),
.waitrequest(sieve_waitrequest),
.readdata   (sieve_readdata),
.readdatavalid (sieve_readdatavalid)
);

assign STX_DBG_LED[9:0] = sieve_ledr;
assign STX_DBG_LED[15:10] = {
  |sieve_hex5,
  |sieve_hex4,
  |sieve_hex3,
  |sieve_hex2,
  |sieve_hex1,
  |sieve_hex0
};
assign DBG_HEADER[6:0] = sieve_hex0;
assign DBG_HEADER[13:7] = sieve_hex1;
assign DBG_HEADER[15:14] = sieve_readdata[1:0];



always_ff @(posedge fpga_clk_50) begin
  FPGA_HB_LED                             <= pb_rst_debounced;
end

endmodule