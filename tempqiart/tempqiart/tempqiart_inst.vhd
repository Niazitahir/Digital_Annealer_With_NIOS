	component tempqiart is
		port (
			clk_clk                   : in  std_logic                     := 'X';             -- clk
			clock_out_clk             : out std_logic;                                        -- clk
			avalon_qsys_waitrequest   : in  std_logic                     := 'X';             -- waitrequest
			avalon_qsys_readdata      : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avalon_qsys_readdatavalid : in  std_logic                     := 'X';             -- readdatavalid
			avalon_qsys_burstcount    : out std_logic_vector(0 downto 0);                     -- burstcount
			avalon_qsys_writedata     : out std_logic_vector(31 downto 0);                    -- writedata
			avalon_qsys_address       : out std_logic_vector(24 downto 0);                    -- address
			avalon_qsys_write         : out std_logic;                                        -- write
			avalon_qsys_read          : out std_logic;                                        -- read
			avalon_qsys_byteenable    : out std_logic_vector(3 downto 0);                     -- byteenable
			avalon_qsys_debugaccess   : out std_logic;                                        -- debugaccess
			reset_out_reset           : out std_logic                                         -- reset
		);
	end component tempqiart;

	u0 : component tempqiart
		port map (
			clk_clk                   => CONNECTED_TO_clk_clk,                   --         clk.clk
			clock_out_clk             => CONNECTED_TO_clock_out_clk,             --   clock_out.clk
			avalon_qsys_waitrequest   => CONNECTED_TO_avalon_qsys_waitrequest,   -- avalon_qsys.waitrequest
			avalon_qsys_readdata      => CONNECTED_TO_avalon_qsys_readdata,      --            .readdata
			avalon_qsys_readdatavalid => CONNECTED_TO_avalon_qsys_readdatavalid, --            .readdatavalid
			avalon_qsys_burstcount    => CONNECTED_TO_avalon_qsys_burstcount,    --            .burstcount
			avalon_qsys_writedata     => CONNECTED_TO_avalon_qsys_writedata,     --            .writedata
			avalon_qsys_address       => CONNECTED_TO_avalon_qsys_address,       --            .address
			avalon_qsys_write         => CONNECTED_TO_avalon_qsys_write,         --            .write
			avalon_qsys_read          => CONNECTED_TO_avalon_qsys_read,          --            .read
			avalon_qsys_byteenable    => CONNECTED_TO_avalon_qsys_byteenable,    --            .byteenable
			avalon_qsys_debugaccess   => CONNECTED_TO_avalon_qsys_debugaccess,   --            .debugaccess
			reset_out_reset           => CONNECTED_TO_reset_out_reset            --   reset_out.reset
		);

