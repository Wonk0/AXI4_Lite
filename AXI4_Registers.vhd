library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--@control_channel_entity_libs
library bupk_2008;																--~ AutoDoc
use bupk_2008.bupk_2008_package.all;											--~ AutoDoc
use bupk_2008.bupk_2008_package_ext.all;										--~ AutoDoc

entity AXI4_Registers is
	generic(
		--@control_channel_generics
		addressing          : tRG_ADDRESSING    := direct_addressing;			--~ AutoDoc
		base_address        : integer           := 0;							--~ AutoDoc
		page_address        : integer           := 0							--~ AutoDoc
	);
	port
	(
		--@control_channel_ports
		CtrlIn      : in    tCtrlIn;											--~ AutoDoc
		CtrlOut     : out   tCtrlOut;											--~ AutoDoc
		ACLK : in std_logic;
		CMD : out std_logic_vector(63 downto 0);
		CMD_WRITTEN : out std_logic;
		DW : out std_logic_vector(7 downto 0);
		DW_WRITTEN : out std_logic;
		DR : in std_logic_vector(7 downto 0);
		DR_READ : out std_logic;
		
		ERROR_S : in std_logic;
		LAST_CMD : in std_logic_vector(2 downto 0);
		LAST_RESP : in std_logic_vector(1 downto 0);
		RESETTING_S : in std_logic;
		WAITING_S : in std_logic;
		HANGED_S : in std_logic;
		COMMAND_EXECUTED : in std_logic;
		FSM_STATE : in std_logic_vector(1 downto 0);
		COUNTER_EXECUTED : in std_logic_vector(7 downto 0)
	);
end entity AXI4_Registers;

--@control_channel_architecture_libs
library bupk_2008;																--~ AutoDoc
use bupk_2008.bupk_2008_package_ext_components.all;								--~ AutoDoc

architecture RTL of AXI4_Registers is
	
	constant RGp_CMDR : tREGISTER_PARAMS := WR_RG(0,8,Resync_Mask=>ON_WRITE,Resync_CLK=>"ACLK"); -- Регистр записи команд
	constant RGp_DWR : tREGISTER_PARAMS := WR_RG(1,1,Resync_Mask => On_Read or On_RD_Access or On_Write or On_WR_Access,Resync_CLK=>"ACLK"); -- Регистр записи данных
	constant RGp_DRR : tREGISTER_PARAMS := RD_RG(2,1,Resync_Mask=>ON_READ,Resync_CLK=>"ACLK"); -- Регистр чтения данных
	constant RGp_SR : tREGISTER_PARAMS := RD_RG(3,4,Resync_Mask=>ON_READ,Resync_CLK=>"ACLK"); -- Регистр текущего состояния шины
	constant RGp_FSMR : tREGISTER_PARAMS := RD_RG(4,4); -- Регистр состояния конечного автомата
	
--@control_channel_declare
-- Control channel signals														--~ AutoDoc
	signal iCtrlIn : tCtrlIn;													--~ AutoDoc
	signal iCtrlOut : tCtrlOut;													--~ AutoDoc
	signal iCtrlOut_mx : tCtrlOut;												--~ AutoDoc
-- Registers signals															--~ AutoDoc
	--Section <none>															--~ AutoDoc
	signal RG_CMDR : tREGWRAPWR_64;												--~ AutoDoc
	signal RG_DRR : tREGWRAPRD_8;												--~ AutoDoc
	signal RG_DWR : tREGWRAPWR_8;												--~ AutoDoc
	signal RG_FSMR : tREGWRAPRD_32;												--~ AutoDoc
	signal RG_SR : tREGWRAPRD_32;												--~ AutoDoc
	
	signal COUNTER_COMMAND_EXECUTED : std_logic_vector(7 downto 0) := (others => '0');
	
begin
	
-- 	Control Channel Access Unit
	U_RG_ACCESS : bupk_2008_addressing
	generic map(
		CORE_TYPE => "AXI4_REGISTERS",
		CORE_VER => 0,
		CORE_REV => 0,
		FILE_PATH=>"$home_path/Hardware/Src/Libraries/Interfacing/AXI4_Lite/AXI4_Registers.vhd",	--NOTE: That string is also auto-updated with script <fix_bupk_2008_addressing.pl>
		addressing => addressing,	
		page_address => page_address,
		base_address => base_address
	)	
	port map(
		CtrlIn => CtrlIn,
		CtrlOut => CtrlOut,
		iCtrlIn => iCtrlIn,
		iCtrlOut => iCtrlOut_mx
	);

--@control_channel_inst
-- Registers instances															--~ AutoDoc
	--Section <none>															--~ AutoDoc
	U_RG_CMDR : bupk_2008_io_reg_resync_wr_common								--~ AutoDoc
	generic map(P=>RGp_CMDR)													--~ AutoDoc
	port map(																	--~ AutoDoc
		CtrlIn => iCtrlIn,														--~ AutoDoc
		Q => RG_CMDR.Q, --> DROP												--~ AutoDoc
		OUTPUT => RG_CMDR.OUTPUT,												--~ AutoDoc
		RESYNC_BUSY => RG_CMDR.RESYNC_BUSY,										--~ AutoDoc
		RESYNC_C => ACLK,														--~ AutoDoc
		EVENT => RG_CMDR.EVENT,													--~ AutoDoc
		STATE => RG_CMDR.STATE,													--~ AutoDoc
		RST_BUSY => '0'															--~ AutoDoc
	);																			--~ AutoDoc
	U_RG_DRR : bupk_2008_io_reg_resync_rd_common								--~ AutoDoc
	generic map(P=>RGp_DRR)														--~ AutoDoc
	port map(																	--~ AutoDoc
		CtrlIn => iCtrlIn,														--~ AutoDoc
		D => RG_DRR.D, --> DROP													--~ AutoDoc
		OUTPUT => RG_DRR.OUTPUT,												--~ AutoDoc
		RESYNC_BUSY => RG_DRR.RESYNC_BUSY,										--~ AutoDoc
		RESYNC_C => ACLK,														--~ AutoDoc
		EVENT => RG_DRR.EVENT,													--~ AutoDoc
		STATE => RG_DRR.STATE,													--~ AutoDoc
		RST_BUSY => '0'															--~ AutoDoc
	);																			--~ AutoDoc
	U_RG_DWR : bupk_2008_io_reg_resync_wr_common								--~ AutoDoc
	generic map(P=>RGp_DWR)														--~ AutoDoc
	port map(																	--~ AutoDoc
		CtrlIn => iCtrlIn,														--~ AutoDoc
		Q => RG_DWR.Q, --> DROP													--~ AutoDoc
		OUTPUT => RG_DWR.OUTPUT,												--~ AutoDoc
		RESYNC_BUSY => RG_DWR.RESYNC_BUSY,										--~ AutoDoc
		RESYNC_C => ACLK,														--~ AutoDoc
		EVENT => RG_DWR.EVENT,													--~ AutoDoc
		STATE => RG_DWR.STATE,													--~ AutoDoc
		RST_BUSY => '0'															--~ AutoDoc
	);																			--~ AutoDoc
	U_RG_FSMR : bupk_2008_io_reg_rd_common										--~ AutoDoc
	generic map(P=>RGp_FSMR)													--~ AutoDoc
	port map(																	--~ AutoDoc
		CtrlIn => iCtrlIn,														--~ AutoDoc
		D => RG_FSMR.D, --> DROP												--~ AutoDoc
		OUTPUT => RG_FSMR.OUTPUT,												--~ AutoDoc
		EVENT => RG_FSMR.EVENT,													--~ AutoDoc
		STATE => RG_FSMR.STATE,													--~ AutoDoc
		RST_BUSY => '0'															--~ AutoDoc
	);																			--~ AutoDoc
	U_RG_SR : bupk_2008_io_reg_resync_rd_common									--~ AutoDoc
	generic map(P=>RGp_SR)														--~ AutoDoc
	port map(																	--~ AutoDoc
		CtrlIn => iCtrlIn,														--~ AutoDoc
		D => RG_SR.D, --> DROP													--~ AutoDoc
		OUTPUT => RG_SR.OUTPUT,													--~ AutoDoc
		RESYNC_BUSY => RG_SR.RESYNC_BUSY,										--~ AutoDoc
		RESYNC_C => ACLK,														--~ AutoDoc
		EVENT => RG_SR.EVENT,													--~ AutoDoc
		STATE => RG_SR.STATE,													--~ AutoDoc
		RST_BUSY => '0'															--~ AutoDoc
	);																			--~ AutoDoc
	iCtrlOut <= MUX_RGS((														--~ AutoDoc
		RG_CMDR.OUTPUT,															--~ AutoDoc
		RG_DRR.OUTPUT,															--~ AutoDoc
		RG_DWR.OUTPUT,															--~ AutoDoc
		RG_FSMR.OUTPUT,															--~ AutoDoc
		RG_SR.OUTPUT															--~ AutoDoc
	),iCtrlIn);																	--~ AutoDoc
	iCtrlOut_mx <= iCtrlOut;													--~ AutoDoc
	
	CMD <= RG_CMDR.Q;
	CMD_WRITTEN <= RG_CMDR.STATE.WRITTEN;
	DW <= RG_DWR.Q;
	DW_WRITTEN <= RG_DWR.STATE.WRITTEN;
	DR_READ <= RG_DRR.EVENT.READ;
	RG_DRR.D <= DR;
	
	p_WR_SR : process(ACLK) is 
	begin
		if rising_edge(ACLK) then
			
			RG_SR.D(0) <= COMMAND_EXECUTED; --> MAP C Признак выполнения команды
			RG_SR.D(1) <= HANGED_S; --> MAP H Признак зависания шины
			RG_SR.D(2) <= WAITING_S; --> MAP W Признак выполнения команды ожидания
			RG_SR.D(3) <= RESETTING_S; --> MAP R Признак выполнения команды сброса
			RG_SR.D(9 downto 8) <= LAST_RESP; --> MAP LAST_RESP Ответ на последнюю принятую  команду
			RG_SR.D(14 downto 12) <= LAST_CMD; --> MAP LAST_CMD Код последней принятой команды
			RG_SR.D(15) <= ERROR_S; --> MAP E Признак ошибки протокола работы с интерфейсом
			RG_SR.D(23 downto 16) <= COUNTER_EXECUTED; --> MAP COUNTER Счетчик выполненных команд
		end if;
	end process;
	
	RG_FSMR.D(1 downto 0) <= FSM_STATE; --> MAP STATE Состояние автомата "00" - idle, "01" - end_rd, "11" - end_wr
	
end architecture RTL;