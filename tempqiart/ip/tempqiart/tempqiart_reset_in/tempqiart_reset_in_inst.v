	tempqiart_reset_in u0 (
		.clk         (_connected_to_clk_),         //   input,  width = 1,         clk.clk
		.in_reset    (_connected_to_in_reset_),    //   input,  width = 1,    in_reset.reset
		.out_reset   (_connected_to_out_reset_),   //  output,  width = 1,   out_reset.reset
		.out_reset_1 (_connected_to_out_reset_1_)  //  output,  width = 1, out_reset_1.reset
	);

