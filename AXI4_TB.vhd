library ieee;
use ieee.std_logic_1164.all;

entity AXI4_TB is
end entity AXI4_TB;

--@control_channel_entity_libs
library bupk_2008;																--~ AutoDoc
use bupk_2008.bupk_2008_package.all;											--~ AutoDoc
use bupk_2008.bupk_2008_package_ext.all;										--~ AutoDoc

----@control_channel_architecture_libs
--library bupk_2008;																--~ AutoDoc
--use bupk_2008.bupk_2008_package_ext_components.all;								--~ AutoDoc

library bupk_2003;
use bupk_2003.bupk_2003_Package.all;
use bupk_2003.bupk_2003_simulation.all;

--library common_HDL;
--use common_HDL.general_types.all;

use work.components.all;
use work.AXI_API_TO_CC.all;

architecture RTL of AXI4_TB is
	
	signal CtrlIn : tCtrlIn;
	signal CtrlOut : tCtrlOut;
	
	signal AD   : STD_LOGIC:= '1';
	signal RD   : STD_LOGIC:= '1';
	signal WR   : STD_LOGIC:= '1';
	signal CS   : STD_LOGIC:= '1';
	signal RST  : STD_LOGIC:= '1';
	signal SIR  : std_logic := '0';
	signal D    : STD_LOGIC_VECTOR(7 downto 0);
	signal BUSY : STD_LOGIC:= '1';
	
	signal ACLK : std_logic := '0';
	signal CMD : std_logic_vector(63 downto 0);
	signal CMD_WRITTEN : std_logic;
	signal DW : std_logic_vector(7 downto 0);
	signal DW_WRITTEN : std_logic;
	signal DR : std_logic_vector(7 downto 0);
	signal DR_READ : std_logic;
	
	signal S_AXI_ARESETN : std_logic;
	signal AXI_AWADDR	 : std_logic_vector(31 downto 0);
	signal S_AXI_AWADDR	 : std_logic_vector(10 downto 0);
	signal S_AXI_AWVALID : std_logic;
	signal S_AXI_AWREADY : std_logic;
	signal S_AXI_WDATA	 : std_logic_vector(31 downto 0);
	signal S_AXI_WSTRB	 : std_logic_vector(3 downto 0);
	signal S_AXI_WVALID	 : std_logic;
	signal S_AXI_WREADY	 : std_logic;
	signal S_AXI_BRESP	 : std_logic_vector(1 downto 0);
	signal S_AXI_BVALID	 : std_logic;
	signal S_AXI_BREADY	 : std_logic;
	signal AXI_ARADDR	 : std_logic_vector(31 downto 0);
	signal S_AXI_ARADDR	 : std_logic_vector(10 downto 0);
	signal S_AXI_ARVALID : std_logic;
	signal S_AXI_ARREADY : std_logic;
	signal S_AXI_RDATA	 : std_logic_vector(31 downto 0);
	signal S_AXI_RRESP	 : std_logic_vector(1 downto 0);
	signal S_AXI_RVALID	 : std_logic;
	signal S_AXI_RREADY	 : std_logic;
	signal S_PROT		 : std_logic_vector(2 downto 0) := (others => '0');
	signal ERROR_S		 : std_logic;
	signal LAST_CMD		 : std_logic_vector(2 downto 0);
	signal LAST_RESP	 : std_logic_vector(1 downto 0);
	signal RESETTING_S	 : std_logic;
	signal WAITING_S	 : std_logic;
	signal HANGED_S		 : std_logic;
	signal COMMAND_EXECUTED : std_logic;
	signal FSM_STATE     : std_logic_vector(1 downto 0);
	signal COUNTER_EXECUTED : std_logic_vector(7 downto 0);
	
	signal CTRL_INGRESS  : std_logic_vector(4 downto 0);
	signal CTRL_EGRESS : std_logic_vector(0 downto 0);
	signal CTRL_IO : std_logic_vector(7 downto 0);
	signal addr : natural;
	signal size : natural;
	signal count : natural;
	signal incr : integer;
		
	component myip_1_v1_0_S00_AXI is
	generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 11
	);
	port (
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
	);
	end component;
	
begin
	
	my_io_block : io_block
	port map(
		nCS => CTRL_INGRESS(0),
		SIR => SIR,
		nWR => CTRL_INGRESS(2),
		nRD => CTRL_INGRESS(3),
		AD => CTRL_INGRESS(1),
		Busy => CTRL_EGRESS(0),
		D => CTRL_IO,
		
		Busy_IN => CtrlOut.BUSY,
		Di        => CtrlOut.D,
		Do        => CtrlIn.D,
		ADR       => CtrlIn.ADR,
		WR_Strobe => CtrlIn.WR_Strobe,
		RD_Strobe => CtrlIn.RD_Strobe,
		AD_Strobe => CtrlIn.AD_Strobe,
		NOW_RD    => CtrlIn.NOW_RD,
		NOW_WR    => CtrlIn.NOW_WR,
		NOW_IDLE  => CtrlIn.NOW_IDL
	);
	
	CtrlIn.SIR <= SIR;
	SIR <= not SIR after 20 ns;
	ACLK <= not ACLK after 10 ns;
	
	U_Registers : AXI4_Registers
		generic map(
			addressing   => direct_addressing,
			base_address => 0,
			page_address => 0
		)
		port map
		(
			CtrlIn      => CtrlIn,
			CtrlOut     => CtrlOut,
			ACLK        => ACLK,
			CMD         => CMD,
			CMD_WRITTEN => CMD_WRITTEN,
			DW          => DW,
			DW_WRITTEN  => DW_WRITTEN,
			DR          => DR,
			DR_READ     => DR_READ,
			ERROR_S     => ERROR_S,
			LAST_CMD    => LAST_CMD,
			LAST_RESP   => LAST_RESP,
			RESETTING_S => RESETTING_S,
			WAITING_S   => WAITING_S,
			HANGED_S    => HANGED_S,
			COMMAND_EXECUTED => COMMAND_EXECUTED,
			FSM_STATE       => FSM_STATE,
			COUNTER_EXECUTED => COUNTER_EXECUTED
		);
		
	U_Master : AXI4_Master
		port map(
			ACLK            => ACLK,
			CMD             => CMD,
			CMD_WRITTEN     => CMD_WRITTEN,
			DW              => DW,
			DW_WRITTEN      => DW_WRITTEN,
			DR              => DR,
			DR_READ         => DR_READ,
			
			ERROR_S         => ERROR_S,
			LAST_CMD        => LAST_CMD,
			LAST_RESP       => LAST_RESP,
			RESETTING_S     => RESETTING_S,
			WAITING_S       => WAITING_S,
			HANGED_S        => HANGED_S,
			COMMAND_EXECUTED => COMMAND_EXECUTED,
			FSM_STATE       => FSM_STATE,
			COUNTER_EXECUTED => COUNTER_EXECUTED,
			
			ARESETn     => S_AXI_ARESETN,
			AXI_ARVALID => S_AXI_ARVALID,
			AXI_ARREADY => S_AXI_ARREADY,
			AXI_ARADDR  => AXI_ARADDR,
			
			AXI_RVALID  => S_AXI_RVALID,
			AXI_RREADY  => S_AXI_RREADY,
			AXI_RDATA   => S_AXI_RDATA,
			AXI_RRESP   => S_AXI_RRESP,
			
			AXI_AWVALID => S_AXI_AWVALID,
			AXI_AWREADY => S_AXI_AWREADY,
			AXI_AWADDR  => AXI_AWADDR,
			
			AXI_WVALID  => S_AXI_WVALID,
			AXI_WREADY  => S_AXI_WREADY,
			AXI_WDATA   => S_AXI_WDATA,
			AXI_WSTRB   => S_AXI_WSTRB,
			
			AXI_BVALID  => S_AXI_BVALID,
			AXI_BREADY  => S_AXI_BREADY,
			AXI_BRESP   => S_AXI_BRESP
	);
	
	S_AXI_ARADDR <= AXI_ARADDR(10 downto 0);
	S_AXI_AWADDR <= AXI_AWADDR(10 downto 0);
	
	u_Slave : myip_1_v1_0_S00_AXI
	generic map (
		C_S_AXI_DATA_WIDTH	=> 32,
		C_S_AXI_ADDR_WIDTH	=> 11
	)
	port map (
		S_AXI_ACLK		=> ACLK,
		S_AXI_ARESETN	=> S_AXI_ARESETN,
		S_AXI_AWADDR	=> S_AXI_AWADDR,
		S_AXI_AWPROT	=> S_PROT,
		S_AXI_AWVALID	=> S_AXI_AWVALID,
		S_AXI_AWREADY	=> S_AXI_AWREADY,
		S_AXI_WDATA		=> S_AXI_WDATA,
		S_AXI_WSTRB		=> S_AXI_WSTRB,
		S_AXI_WVALID	=> S_AXI_WVALID,
		S_AXI_WREADY	=> S_AXI_WREADY,
		S_AXI_BRESP		=> S_AXI_BRESP,
		S_AXI_BVALID	=> S_AXI_BVALID,
		S_AXI_BREADY	=> S_AXI_BREADY,
		S_AXI_ARADDR	=> S_AXI_ARADDR,
		S_AXI_ARPROT	=> S_PROT,
		S_AXI_ARVALID	=> S_AXI_ARVALID,
		S_AXI_ARREADY	=> S_AXI_ARREADY,
		S_AXI_RDATA		=> S_AXI_RDATA,
		S_AXI_RRESP		=> S_AXI_RRESP,
		S_AXI_RVALID	=> S_AXI_RVALID,
		S_AXI_RREADY	=> S_AXI_RREADY
	);
	
	p_BUPK : process is
		variable WDATA : slv8_array(0 to 1023);
		variable RDATA : slv8_array(0 to 1023);
		variable addr : natural;
		variable size : natural;
		variable count : natural;
		variable incr : integer;
		variable last_responce : natural;
	begin
		
		--Bupk_Init(SIR,CS,AD,WR,RD,D,RST);
		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"01";
--		WDATA(1) := x"00";
--		WDATA(0) := x"04";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
		
		AXI_reset(5,SIR, CTRL_INGRESS, CTRL_EGRESS, CTRL_IO);

		wait for 100 ns;
		
		AXI_wait(10,SIR, CTRL_INGRESS, CTRL_EGRESS, CTRL_IO);
		
		WDATA(7) := x"88";
		WDATA(6) := x"77";
		WDATA(5) := x"66";
		WDATA(4) := x"55";
		WDATA(3) := x"44";
		WDATA(2) := x"33";
		WDATA(1) := x"22";
		WDATA(0) := x"11";
		
		addr := 2;
		size := 1;
		count := 8;
		incr :=1;

		AXI_write(addr,WDATA,size,count,incr,last_responce,SIR, CTRL_INGRESS, CTRL_EGRESS, CTRL_IO);
		
		WDATA(3) := x"DD";
		WDATA(2) := x"CC";
		WDATA(1) := x"BB";
		WDATA(0) := x"AA";
		
		addr := 4;
		size := 4;
		count := 1;
		incr :=0;

		AXI_write(addr,WDATA,size,count,incr,last_responce,SIR, CTRL_INGRESS, CTRL_EGRESS, CTRL_IO);
		
		addr := 4;
		size := 4;
		count := 1;
		incr :=0;
		
		AXI_read(addr,RDATA,size,count,incr,last_responce,SIR, CTRL_INGRESS, CTRL_EGRESS, CTRL_IO);
				
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"00";
--		WDATA(1) := x"02";
--		WDATA(0) := x"00";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"00";
--		WDATA(1) := x"07";
--		WDATA(0) := x"01";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		

--		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"00";
--		WDATA(1) := x"07";
--		WDATA(0) := x"00";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		wait for 200 ns;
--		
--		BUPK_READ_RG(x"02",RDATA,14,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"03";
--		WDATA(1) := x"04";
--		WDATA(0) := x"71";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		WDATA(11) := x"00";
--		WDATA(10) := x"88";
--		WDATA(9) := x"77";
--		WDATA(8) := x"66";
--		WDATA(7) := x"55";
--		WDATA(6) := x"44";
--		WDATA(5) := x"33";
--		WDATA(4) := x"22";
--		WDATA(3) := x"11";
--		WDATA(2) := x"00";
--		WDATA(1) := x"00";
--		WDATA(0) := x"00";
--		BUPK_WRITE_RG(x"01",WDATA,12,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		wait for 4000 ns;
--		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"00";
--		WDATA(1) := x"07";
--		WDATA(0) := x"00";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		wait for 200 ns;
--		
--		BUPK_READ_RG(x"02",RDATA,14,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"0A";
--		WDATA(1) := x"04";
--		WDATA(0) := x"01";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		WDATA(3) := x"00";
--		WDATA(2) := x"AA";
--		WDATA(1) := x"00";
--		WDATA(0) := x"00";
--		BUPK_WRITE_RG(x"01",WDATA,4,SIR,CS,AD,WR,RD,D,BUSY);
		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"FF";
--		WDATA(1) := x"00";
--		WDATA(0) := x"02";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"03";
--		WDATA(1) := x"00";
--		WDATA(0) := x"02";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
--		
--		WDATA(7) := x"00";
--		WDATA(6) := x"00";
--		WDATA(5) := x"00";
--		WDATA(4) := x"00";
--		WDATA(3) := x"00";
--		WDATA(2) := x"03";
--		WDATA(1) := x"00";
--		WDATA(0) := x"04";
--		BUPK_WRITE_RG(x"00",WDATA,8,SIR,CS,AD,WR,RD,D,BUSY);
		
		wait;
	end process;
	
end architecture RTL;