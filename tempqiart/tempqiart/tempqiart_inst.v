	tempqiart u0 (
		.clk_clk                   (_connected_to_clk_clk_),                   //   input,   width = 1,         clk.clk
		.clock_out_clk             (_connected_to_clock_out_clk_),             //  output,   width = 1,   clock_out.clk
		.avalon_qsys_waitrequest   (_connected_to_avalon_qsys_waitrequest_),   //   input,   width = 1, avalon_qsys.waitrequest
		.avalon_qsys_readdata      (_connected_to_avalon_qsys_readdata_),      //   input,  width = 32,            .readdata
		.avalon_qsys_readdatavalid (_connected_to_avalon_qsys_readdatavalid_), //   input,   width = 1,            .readdatavalid
		.avalon_qsys_burstcount    (_connected_to_avalon_qsys_burstcount_),    //  output,   width = 1,            .burstcount
		.avalon_qsys_writedata     (_connected_to_avalon_qsys_writedata_),     //  output,  width = 32,            .writedata
		.avalon_qsys_address       (_connected_to_avalon_qsys_address_),       //  output,  width = 25,            .address
		.avalon_qsys_write         (_connected_to_avalon_qsys_write_),         //  output,   width = 1,            .write
		.avalon_qsys_read          (_connected_to_avalon_qsys_read_),          //  output,   width = 1,            .read
		.avalon_qsys_byteenable    (_connected_to_avalon_qsys_byteenable_),    //  output,   width = 4,            .byteenable
		.avalon_qsys_debugaccess   (_connected_to_avalon_qsys_debugaccess_),   //  output,   width = 1,            .debugaccess
		.reset_out_reset           (_connected_to_reset_out_reset_)            //  output,   width = 1,   reset_out.reset
	);

