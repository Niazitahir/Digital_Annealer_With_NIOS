// (C) 2001-2025 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module  hyperparam_ram_ram_1port_2011_waqxbri  (
    address,
    clock,
    data,
    wren,
    q);

    input  [4:0]  address;
    input    clock;
    input  [31:0]  data;
    input    wren;
    output [31:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
    tri1     clock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

    wire [31:0] sub_wire0;
    wire [31:0] q = sub_wire0[31:0];


    // Instantiate In System Memory Content Editor IP 
    wire reset_out;
    wire [4:0] ismce_addr;
    wire [3:0]ismce_byteena;
    wire [31:0] ismce_wdata;
    wire ismce_wren;
    wire ismce_rden;
    wire [31:0] ismce_rdata;
    wire ismce_waitrequest;
    wire tck_usr;

    //intel_mce_inst intel_mce_component (
    hyperparam_ram_ram_1port_intel_mce_2011_hdk7lli  intel_mce_component (
        .clock0           (clock            ),
        .tck_usr          (tck_usr          ),
        .reset_out        (reset_out        ),
        .ismce_addr       (ismce_addr       ),
        .ismce_byteena    (ismce_byteena    ),
        .ismce_wdata      (ismce_wdata      ),
        .ismce_wren       (ismce_wren       ),
        .ismce_rden       (ismce_rden       ),
        .ismce_rdata      (ismce_rdata      ),
        .ismce_waitrequest(ismce_waitrequest) 
    );    
        // Instantiate Arbiter for ISMCE    
    wire [4:0] arb_addr;
    wire [3:0]arb_byteena;
    wire [31:0] arb_wdata;
    wire arb_wren;
    wire arb_rden;
    wire [31:0] arb_rdata;
    hyperparam_ram_ram_1port_intel_mce_arb_2011_sgmuxea  intel_mce_arb_component (
        .clk              (clock            ),
        .reset            (reset_out        ),
        .uaddr            (address          ),
        .ubyteena         ({4{1'b1}}        ),
        .uwdata           (data             ),
        .urden            (1'b1           ),
        .uwren            (wren             ),
        .uaddressstall    (1'b0   ),
        .urdata           (sub_wire0        ),
        .ismce_addr       (ismce_addr       ),
        .ismce_byteena    (ismce_byteena    ),
        .ismce_wdata      (ismce_wdata      ),
        .ismce_wren       (ismce_wren       ),
        .ismce_rden       (ismce_rden       ),
        .ismce_rdata      (ismce_rdata      ),
        .ismce_waitrequest(ismce_waitrequest),
        .addr             (arb_addr         ),
        .byteena          (arb_byteena      ),
        .wdata            (arb_wdata        ),
        .rden             (arb_rden         ),
        .wren             (arb_wren         ),
        .addressstall     (arb_addressstall ),
        .rdata            (arb_rdata        ) 
    );   

    altera_syncram  altera_syncram_component (
                .address_a (arb_addr),
                .clock0 (clock),
                .data_a (arb_wdata),
                .wren_a (arb_wren),
                .q_a (arb_rdata),
                .aclr0 (1'b0),
                .aclr1 (1'b0),
                .address2_a (1'b1),
                .address2_b (1'b1),
                .address_b (1'b1),
                .addressstall_a (1'b0),
                .addressstall_b (1'b0),
                .byteena_a (1'b1),
                .byteena_b (1'b1),
                .clock1 (1'b1),
                .clocken0 (1'b1),
                .clocken1 (1'b1),
                .clocken2 (1'b1),
                .clocken3 (1'b1),
                .data_b (1'b1),
                .eccencbypass (1'b0),
                .eccencparity (8'b0),
                .eccstatus ( ),
                .q_b ( ),
                .rden_a (1'b1),
                .rden_b (1'b1),
                .sclr (1'b0),
                .wren_b (1'b0));
    defparam
        altera_syncram_component.width_byteena_a  = 1,
        altera_syncram_component.clock_enable_input_a  = "BYPASS",
        altera_syncram_component.clock_enable_output_a  = "BYPASS",
        altera_syncram_component.intended_device_family  = "Stratix 10",
        altera_syncram_component.lpm_type  = "altera_syncram",
        altera_syncram_component.numwords_a  = 32,
        altera_syncram_component.operation_mode  = "SINGLE_PORT",
        altera_syncram_component.outdata_aclr_a  = "NONE",
        altera_syncram_component.outdata_sclr_a  = "NONE",
        altera_syncram_component.outdata_reg_a  = "CLOCK0",
        altera_syncram_component.enable_force_to_zero  = "FALSE",
        altera_syncram_component.power_up_uninitialized  = "FALSE",
        altera_syncram_component.ram_block_type  = "M20K",
        altera_syncram_component.read_during_write_mode_port_a  = "DONT_CARE",
        altera_syncram_component.widthad_a  = 5,
        altera_syncram_component.width_a  = 32;



endmodule

