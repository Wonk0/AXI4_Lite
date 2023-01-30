library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AXI4_Master is
	port(
		ACLK : in std_logic;
		CMD : in std_logic_vector(63 downto 0);
		CMD_WRITTEN : in std_logic;
		DW : in std_logic_vector(7 downto 0);
		DW_WRITTEN : in std_logic;
		DR : out std_logic_vector(7 downto 0);
		DR_READ : in std_logic;
		
		ERROR_S : out std_logic := '0';
		LAST_CMD : out std_logic_vector(2 downto 0) := (others => '0');
		LAST_RESP : out std_logic_vector(1 downto 0) := (others => '0');
		RESETTING_S : out std_logic := '0';
		WAITING_S : out std_logic := '0';
		HANGED_S : out std_logic := '0';
		COMMAND_EXECUTED : out std_logic := '0';
		ARESETn : out std_logic := '0';
		FSM_STATE : out std_logic_vector(1 downto 0) := (others => '0');
		COUNTER_EXECUTED : out std_logic_vector(7 downto 0) := (others => '0');
		
		AXI_ARVALID : out std_logic;
		AXI_ARREADY : in std_logic;
		AXI_ARADDR  : out std_logic_vector(31 downto 0);
		
		AXI_RVALID  : in std_logic;
		AXI_RREADY  : out std_logic;
		AXI_RDATA   : in std_logic_vector(31 downto 0);
		AXI_RRESP   : in std_logic_vector(1 downto 0);
		
		AXI_AWVALID : out std_logic;
		AXI_AWREADY : in std_logic;
		AXI_AWADDR  : out std_logic_vector(31 downto 0);
		
		AXI_WVALID  : out std_logic;
		AXI_WREADY  : in std_logic;
		AXI_WDATA   : out std_logic_vector(31 downto 0);
		AXI_WSTRB   : out std_logic_vector(3 downto 0);
		
		AXI_BVALID  : in std_logic;
		AXI_BREADY  : out std_logic;
		AXI_BRESP   : in std_logic_vector(1 downto 0)
		
	);
end entity AXI4_Master;

library dataflow;
use dataflow.components.all;

architecture RTL of AXI4_Master is
	constant data_width : integer := 8;
	constant data_bus_width : integer := 4;
	signal DW_FIFO : std_logic_vector(31 downto 0);
	signal DR_FIFO : std_logic_vector(31 downto 0);
	signal DR_FIFO_EN : std_logic;
	signal W_FIFO_V : std_logic;
	signal W_FIFO_EN : std_logic;
	signal W_overflow : std_logic;
	
	signal R_overflow : std_logic;
	
	type FSM_GENERAL is (idle,get_data,write,read,hanged,exception,reset,waiting);
	type FSM_COMMAND is (idle,end_wr,end_rd);
	signal state : FSM_GENERAL := idle;
	signal command_state : FSM_COMMAND := idle;
	signal GET_DATA_COUNTER : integer range 0 to 512 := 0;
	signal SEND_DATA_COUNTER : integer range 0 to 512 := 0;
	signal READ_DATA_COUNTER : integer range 0 to 512 := 0;
	signal OPCODE : std_logic_vector(2 downto 0);
	signal SIZE : integer range 0 to 32 := 1;
	signal SIZE_OPERATION : integer range 0 to 32 := 1;
	signal COUNT : integer range 0 to 16 := 0;
	signal INCRIMENT : std_logic := '0';
	signal ACSESS_ADDR : std_logic_vector(31 downto 0) := (others => '0');
	signal TIMER : std_logic_vector(15 downto 0) := (others => '0');
	signal TIME : std_logic_vector(15 downto 0);
	signal iAXI_LAST_CMD : std_logic_vector(2 downto 0);
	signal iAXI_LAST_RESP : std_logic_vector(1 downto 0);
	signal start_comand : std_logic := '0';
	signal shift : integer range 0 to 4 := 0;
	signal COUNTER_COMMAND_EXECUTED : std_logic_vector(7 downto 0) := (others => '0');
	
	signal RRESP_RES : std_logic_vector(1 downto 0) := (others => '0');
	signal BRESP_RES : std_logic_vector(1 downto 0) := (others => '0');
	
	constant cmd_read : std_logic_vector(2 downto 0) := "000";
	constant cmd_write : std_logic_vector(2 downto 0) := "001";
	constant cmd_wait : std_logic_vector(2 downto 0) := "010";
	constant cmd_reset : std_logic_vector(2 downto 0) := "100";
	constant timeout : std_logic_Vector(15 downto 0) := x"FFFF";
	
	signal iAXI_ARESETN : std_logic := '1';
	
	--//chennal write address read
	signal iAXI_ARVALID : std_logic := '0';
	signal iAXI_ARREADY : std_logic := '0';
	signal iAXI_ARADDR : std_logic_vector(31 downto 0) := (others => '0');
	--//chennal read data
	signal iAXI_RVALID : std_logic := '0';
	signal iAXI_RREADY : std_logic := '0';
	signal iAXI_RDATA : std_logic_vector(31 downto 0) := (others => '0');
	signal iAXI_RRESP : std_logic_vector(1 downto 0) := (others => '0');
	--//chennal write address write
	signal iAXI_AWVALID : std_logic := '0';
	signal iAXI_AWREADY : std_logic := '0';
	signal iAXI_AWADDR : std_logic_vector(31 downto 0) := (others => '0');
	--//chennal write data
	signal iAXI_WVALID : std_logic := '0';
	signal iAXI_WREADY : std_logic := '0';
	signal iAXI_WDATA : std_logic_vector(31 downto 0) := (others => '0');
	signal iAXI_WSTRB : std_logic_vector(3 downto 0) := (others => '0');
	--//chennal reply
	signal iAXI_BVALID : std_logic := '0';
	signal iAXI_BREADY : std_logic := '0';
	signal iAXI_BRESP : std_logic_vector(1 downto 0) := (others => '0');
	
begin
	
	ARESETn <= iAXI_ARESETN;
	
	AXI_ARVALID  <= iAXI_ARVALID;
	iAXI_ARREADY <= AXI_ARREADY;
	AXI_ARADDR   <= iAXI_ARADDR;
	
	iAXI_RVALID  <= AXI_RVALID;
	AXI_RREADY   <= iAXI_RREADY;
	iAXI_RDATA   <= AXI_RDATA;
	iAXI_RRESP   <= AXI_RRESP;
	
	AXI_AWVALID  <= iAXI_AWVALID;
	iAXI_AWREADY <= AXI_AWREADY;
	AXI_AWADDR   <= iAXI_AWADDR;
	
	AXI_WVALID   <= iAXI_WVALID;
	iAXI_WREADY  <= AXI_WREADY;
	AXI_WDATA    <= iAXI_WDATA;
	AXI_WSTRB    <= iAXI_WSTRB;
	
	iAXI_BVALID  <= AXI_BVALID;
	AXI_BREADY   <= iAXI_BREADY;
	iAXI_BRESP   <= AXI_BRESP;
	
	LAST_CMD     <= iAXI_LAST_CMD;
	LAST_RESP    <= iAXI_LAST_RESP;
	
	FSM_STATE    <= "00" when command_state = idle else "01" when command_state = end_rd
                                                   else "11" when command_state = end_wr;

    COUNTER_EXECUTED <= COUNTER_COMMAND_EXECUTED;

	wr_fifo : sfifo_wrap
		generic map(
			WR_Width            => data_width,
			RD_Width            => data_bus_width * 8,
			WR_Depth            => 512,
			FWFT                => true,
			RAMSTYLE            => "auto"
		)
		port map(
			din           => DW,
			wr_en         => DW_WRITTEN,
			dout          => DW_FIFO,
			valid         => W_FIFO_V,
			rd_en         => W_FIFO_EN,
			full          => open,
			almost_full   => open,
			almost_empty  => open,
			empty         => open,
			overflow      => W_overflow,
			underflow     => open,
			wr_data_count => open,
			rd_data_count => open,
			clk           => ACLK,
			rst           => '0'
		);
		
	rd_fifo : sfifo_wrap
		generic map(
			WR_Width            => data_bus_width * 8,
			RD_Width            => data_width,
			WR_Depth            => 512,
			FWFT                => true,
			RAMSTYLE            => "auto"
		)
		port map(
			din           => DR_FIFO,
			wr_en         => DR_FIFO_EN,
			dout          => DR,
			valid         => open,
			rd_en         => DR_READ,
			full          => open,
			almost_full   => open,
			almost_empty  => open,
			empty         => open,
			overflow      => R_overflow,
			underflow     => open,
			wr_data_count => open,
			rd_data_count => open,
			clk           => ACLK,
			rst           => '0'
		);
		
		DATA_count : process(ACLK) is
		begin
			if rising_edge(ACLK) then
				if DW_WRITTEN = '1' then
					GET_DATA_COUNTER <= GET_DATA_COUNTER + 1;
				end if;
				if CMD_WRITTEN = '1' then
					GET_DATA_COUNTER <= 0;
				end if;
			end if;
		end process;

		iAXI_WDATA <= DW_FIFO;
		
		OPCODE <= CMD(2 downto 0);
		COUNT <= to_integer(unsigned(CMD(7 downto 4))) + 1;
		INCRIMENT <= CMD(10);
		TIME <= CMD(31 downto 16);
		
		p_MUX_DADA : process(ACLK) is
		variable Assending_ADDR : std_logic_vector(31 downto 0) := (others => '0');
		variable SEND_DATA : integer range 0 to 512 := 0;
		begin
			if rising_edge(ACLK) then
				W_FIFO_EN <= '0';
				iAXI_WSTRB <= (others => '0');
				if CMD_WRITTEN = '1' then
					
					if CMD(9 downto 8) = "00" then
						SIZE <= 1;
						SIZE_OPERATION <= 1;
					elsif CMD(9 downto 8) = "01" then
						SIZE <= 2;
						SIZE_OPERATION <= 2;
					elsif CMD(9 downto 8) = "10" then
						SIZE <= 4;
						SIZE_OPERATION <= 4;
					elsif CMD(9 downto 8) = "11" then
						SIZE <= 8;
						SIZE_OPERATION <= 4;
					end if;
					
					iAXI_LAST_CMD <= OPCODE;
					
					shift <= to_integer(unsigned(CMD(17 downto 16)));
					if OPCODE = cmd_write or OPCODE = cmd_read then
						ACSESS_ADDR <= CMD(47 downto 16);
					end if;
				end if;
				
				if iAXI_RVALID = '1' or iAXI_BVALID = '1' then
					if INCRIMENT = '1' then
						if shift + SIZE_OPERATION > 3 then
							Assending_ADDR := ACSESS_ADDR(31 downto 2) & "00";
							ACSESS_ADDR <= std_logic_vector(unsigned(Assending_ADDR) + data_bus_width);
						end if;
					end if;
				end if;
				
				SEND_DATA := SIZE * COUNT - SIZE_OPERATION;
				if iAXI_BVALID = '1' then
					if SEND_DATA_COUNTER < SEND_DATA then
						if shift + SIZE_OPERATION > 3 then
							shift <= 0;
							W_FIFO_EN <= '1';
						else
							shift <= shift + SIZE_OPERATION;
						end if;
					elsif SEND_DATA_COUNTER >= SEND_DATA then
						W_FIFO_EN <= '1';
					end if;
				end if;
				
				if SIZE >= 4 then
					iAXI_WSTRB <= "1111";
				elsif SIZE = 2 then
					iAXI_WSTRB(shift + 2 - 1 downto shift) <= "11";
				elsif SIZE = 1 then
					iAXI_WSTRB(shift) <= '1';
				end if;
				
			end if;
		end process;
		
		p_FSM : process(ACLK) is
			variable expected_data : integer range 0 to 512 := 0; 
		begin
			if rising_edge(ACLK) then
				DR_FIFO_EN <= '0';
				case state is
					when idle =>
						if CMD_WRITTEN = '1' then
							SEND_DATA_COUNTER <= 0;
							READ_DATA_COUNTER <= 0;
							if CMD(2 downto 0) = cmd_read then
								COMMAND_EXECUTED <= '1';
								TIMER <= timeout;
								start_comand <= '1';
								state <= read;
							elsif CMD(2 downto 0) = cmd_write then
								state <= get_data;
								COMMAND_EXECUTED <= '1';
							elsif CMD(2 downto 0) = cmd_wait then
								TIMER <= TIME;
								WAITING_S <= '1';
								state <= waiting;
							elsif CMD(2 downto 0) = cmd_reset then
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								RESETTING_S <= '1';
								state <= reset;
							end if;
						end if;
					when get_data =>
						expected_data := ((shift + SIZE * COUNT) + data_bus_width - 1) / data_bus_width *data_bus_width;
						if GET_DATA_COUNTER = expected_data then
							TIMER <= timeout;
							start_comand <= '1';
							state <= write;
						end if;
						if CMD_WRITTEN = '1' then
							COMMAND_EXECUTED <= '0';
							if OPCODE = cmd_reset then
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								RESETTING_S <= '1';
								state <= reset;
							else
								ERROR_S <= '1';
								COMMAND_EXECUTED <= '0';
								start_comand <= '0';
								state <= exception;
							end if;
						end if;
					when write =>
						TIMER <= std_logic_vector(unsigned(TIMER) - 1);
						if iAXI_BVALID = '1'then
							SEND_DATA_COUNTER <= SEND_DATA_COUNTER  + SIZE_OPERATION;
							if BRESP_RES = "00" then
								BRESP_RES <= iAXI_BRESP;
							end if;
							if SEND_DATA_COUNTER < SIZE * COUNT - SIZE_OPERATION then
								TIMER <= timeout;
								start_comand <= '1';
							else
								COMMAND_EXECUTED <= '0';
								start_comand <= '0';
								iAXI_LAST_RESP <= BRESP_RES;
								state <= idle;
								COUNTER_COMMAND_EXECUTED <= std_logic_vector(unsigned(COUNTER_COMMAND_EXECUTED) + 1);
							end if;
						end if;
						if CMD_WRITTEN = '1' then
							COMMAND_EXECUTED <= '0';
							if OPCODE = cmd_reset then
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								RESETTING_S <= '1';
								state <= reset;
							else
								ERROR_S <= '1';
								COMMAND_EXECUTED <= '0';
								start_comand <= '0';
								state <= exception;
							end if;
						end if;
						if DW_WRITTEN = '1' then
							COMMAND_EXECUTED <= '0';
							start_comand <= '0';
							ERROR_S <= '1';
							state <= exception;
						end if;
						if TIMER = x"0000" then
							COMMAND_EXECUTED <= '0';
							start_comand <= '0';
							HANGED_S <= '1';
							state <= hanged;
						end if;
					when read =>
						TIMER <= std_logic_vector(unsigned(TIMER) - 1);
						if iAXI_RVALID = '1' then
							READ_DATA_COUNTER <= READ_DATA_COUNTER + SIZE_OPERATION;
							DR_FIFO <= iAXI_RDATA;
							DR_FIFO_EN <= '1';
							if RRESP_RES = "00" then
								RRESP_RES <= iAXI_RRESP;
							end if;
							if READ_DATA_COUNTER < SIZE * COUNT - SIZE_OPERATION then
								TIMER <= timeout;
								start_comand <= '1';
							else
								COMMAND_EXECUTED <= '0';
								start_comand <= '0';
								iAXI_LAST_RESP <= RRESP_RES;
								state <= idle;
								COUNTER_COMMAND_EXECUTED <= std_logic_vector(unsigned(COUNTER_COMMAND_EXECUTED) + 1);
							end if;
						end if; 
						
						if CMD_WRITTEN = '1' then
							COMMAND_EXECUTED <= '0';
							if OPCODE = cmd_reset then
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								RESETTING_S <= '1';
								state <= reset;
							else
								ERROR_S <= '1';
								state <= exception;
							end if;
						end if;
						if TIMER = x"0000" then
							COMMAND_EXECUTED <= '0';
							start_comand <= '0';
							HANGED_S <= '1';
							state <= hanged;
						end if;
					when waiting =>
						TIMER <= std_logic_vector(unsigned(TIMER) - 1);
						if TIMER = x"0000" then
							WAITING_S <= '0';
							state <= idle;
						end if;
						if CMD_WRITTEN = '1' then
							WAITING_S <= '0';
							if OPCODE = cmd_reset then
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								RESETTING_S <= '1';
								state <= reset;
							else
								ERROR_S <= '1';
								state <= exception;
							end if;
						end if;
					when reset =>
						TIMER <= std_logic_vector(unsigned(TIMER) - 1);
						if TIMER = x"0000" then
							RESETTING_S <= '0';
							iAXI_ARESETN <= '1';
							state <= idle;
						end if;
						if CMD_WRITTEN = '1' then
							RESETTING_S <= '0';
							if OPCODE = cmd_reset then
								RESETTING_S <= '1';
								if TIMER < TIME then
									TIMER <= TIME;
								end if;
							else
								ERROR_S <= '1';
								state <= exception;
							end if;
						end if;
					when hanged=>
						if CMD_WRITTEN = '1' then
							if OPCODE = cmd_reset then
								RESETTING_S <= '1';
								HANGED_S <= '0';
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								state <= reset;
							end if;
						end if;
					when exception =>
						if CMD_WRITTEN = '1' then
							if OPCODE = cmd_reset then
								RESETTING_S <= '1';
								ERROR_S <= '0';
								TIMER <= TIME;
								iAXI_ARESETN <= '0';
								state <= reset;
							end if;
						end if;
				end case;
			end if;
		end process;
		
		COMMAND : process(ACLK) is
		begin
			if rising_edge(ACLK) then
				case command_state is 
					when idle =>
						if start_comand = '1' then
							if OPCODE = cmd_read then
								iAXI_ARVALID <= '1';
								iAXI_RREADY <= '1';
								iAXI_ARADDR <= ACSESS_ADDR;
								command_state <= end_rd;
							elsif OPCODE = cmd_write then
								iAXI_BREADY <= '1';
								iAXI_AWADDR <= ACSESS_ADDR;
								iAXI_AWVALID <= '1';
								iAXI_WVALID <= '1';
								command_state <= end_wr;
							end if;
						end if;
					when end_rd =>
						if iAXI_ARREADY = '1' and iAXI_ARVALID = '1' then
							iAXI_ARVALID <= '0';
						end if;
						if iAXI_RVALID = '1' and iAXI_RREADY = '1' then
							iAXI_RREADY <= '0';
							command_state <= idle;
						end if;
					when end_wr =>
						if iAXI_AWVALID = '1' and iAXI_AWREADY = '1' then
							iAXI_AWVALID <= '0';
						end if;
						if iAXI_WVALID = '1' and iAXI_WREADY = '1' then
							iAXI_WVALID <= '0';
						end if;
						if iAXI_BREADY = '1' and iAXI_BVALID = '1' then
							iAXI_BREADY <= '0';
							command_state <= idle;
						end if;
				end case;
			end if;
		end process;

end architecture RTL;