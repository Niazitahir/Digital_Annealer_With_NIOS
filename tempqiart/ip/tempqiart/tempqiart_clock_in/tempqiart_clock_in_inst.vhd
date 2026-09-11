	component tempqiart_clock_in is
		port (
			in_clk    : in  std_logic := 'X'; -- clk
			out_clk   : out std_logic;        -- clk
			out_clk_1 : out std_logic         -- clk
		);
	end component tempqiart_clock_in;

	u0 : component tempqiart_clock_in
		port map (
			in_clk    => CONNECTED_TO_in_clk,    --    in_clk.clk
			out_clk   => CONNECTED_TO_out_clk,   --   out_clk.clk
			out_clk_1 => CONNECTED_TO_out_clk_1  -- out_clk_1.clk
		);

