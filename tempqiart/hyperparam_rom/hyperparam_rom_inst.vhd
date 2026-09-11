	component hyperparam_rom is
		port (
			q       : out std_logic_vector(31 downto 0);                    -- dataout
			address : in  std_logic_vector(4 downto 0)  := (others => 'X'); -- address
			clock   : in  std_logic                     := 'X'              -- clk
		);
	end component hyperparam_rom;

	u0 : component hyperparam_rom
		port map (
			q       => CONNECTED_TO_q,       --       q.dataout
			address => CONNECTED_TO_address, -- address.address
			clock   => CONNECTED_TO_clock    --   clock.clk
		);

