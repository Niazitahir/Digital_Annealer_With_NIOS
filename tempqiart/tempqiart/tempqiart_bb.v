module tempqiart (
		input  wire        clk_clk,                   //         clk.clk
		output wire        clock_out_clk,             //   clock_out.clk
		input  wire        avalon_qsys_waitrequest,   // avalon_qsys.waitrequest
		input  wire [31:0] avalon_qsys_readdata,      //            .readdata
		input  wire        avalon_qsys_readdatavalid, //            .readdatavalid
		output wire [0:0]  avalon_qsys_burstcount,    //            .burstcount
		output wire [31:0] avalon_qsys_writedata,     //            .writedata
		output wire [24:0] avalon_qsys_address,       //            .address
		output wire        avalon_qsys_write,         //            .write
		output wire        avalon_qsys_read,          //            .read
		output wire [3:0]  avalon_qsys_byteenable,    //            .byteenable
		output wire        avalon_qsys_debugaccess,   //            .debugaccess
		output wire        reset_out_reset            //   reset_out.reset
	);
endmodule

