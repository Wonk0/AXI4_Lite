library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;


package AXI_API_TO_CC is
	type slv8_array is array (natural range<>) of std_logic_vector(7 downto 0);
	
	procedure Bupk_Write_RG(
		ADDR		: std_logic_vector(7 downto 0);
		Data		: slv8_array;
		Length		: integer;
		signal SIR	: in std_logic;
		signal nCS	: out std_logic;
		signal AD	: out std_logic;
		signal nWR	: out std_logic;
		signal nRD	: out std_logic;
		signal D	: out std_logic_vector(7 downto 0);
		signal Busy	: in STD_LOGIC
	);
	
	procedure Bupk_Read_RG(
		ADDR		: std_logic_vector(7 downto 0);
		Data		: out slv8_array;
		Length		: integer;
		signal SIR	: in std_logic;
		signal nCS	: out std_logic;
		signal AD	: out std_logic;
		signal nWR	: out std_logic;
		signal nRD	: out std_logic;
		signal D	: inout std_logic_vector(7 downto 0);
		signal Busy	: in STD_LOGIC
	);
	
	procedure AXI_reset(
		hold_us : natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	);
	
	procedure AXI_wait(
		hold_us : natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	);

	procedure AXI_state(
		cmd_count : out natural;
		error : out natural;
		last_cmd : out natural;
		last_resp : out natural;
		resetting : out natural;
		waiting : out natural;
		hanged : out natural;
		command_executed : out natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	);

	procedure AXI_write(
		addr : natural;
		data : slv8_array;
		size : natural;
		count : natural;
		incr : integer;
		last_resp : out natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
		
	);

	procedure AXI_read(
		addr : natural;
		data : out slv8_array;
		size : natural;
		count : natural;
		incr : integer;
		last_resp : out natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	);

end AXI_API_TO_CC;

package body AXI_API_TO_CC is

	function slv_to_slv8a(a:std_logic_vector;network_order:boolean:=false) return slv8_array is
		constant result_length : integer:= a'length/8;
		variable result : slv8_array(0 to result_length-1):=(others => x"00");
		variable d : std_logic_vector(a'high downto a'low);
	begin
		-- TODO: check that a'length is a multiple of 8
		-- TODO: check that a is descending range
		for i in a'low to a'high loop
			d(i):=a(i);
		end loop;
		for i in 0 to result_length-1 loop
			if network_order then
				result(result'high-i) := d(d'low+i*8+7 downto d'low+i*8);
			else
				result(i) := d(d'low+i*8+7 downto d'low+i*8);
			end if;
		end loop;
		return result;
	end function;
	
	constant Default_Bupk_Delay_Period	: integer range 0 to 512:=0;
	constant Bupk_Delay_Time : integer range 0 to 32 :=5;
	constant BUPK_new_channel : std_logic :='1';
	
	procedure Bupk_Write_RG(
		ADDR		: std_logic_vector(7 downto 0);
		Data		: slv8_array;
		Length		: integer;
		signal SIR	: in std_logic;
		signal nCS	: out std_logic;
		signal AD	: out std_logic;
		signal nWR	: out std_logic;
		signal nRD	: out std_logic;
		signal D	: out std_logic_vector(7 downto 0);
		signal Busy	: in STD_LOGIC
		--
	) is
	variable Count_Bytes_After_Delay	: integer:=0;
	variable Count_Delay_Clocks			: integer range 32 downto 0:=0;
	variable Count_Bytes				: integer:=0;
	constant Bupk_Delay_Period	: integer range 0 to 512 := 0;
	begin
		wait until SIR='0';
			nCS<='0';
			AD<='1';
			nWR<='0';
			nRD<='1';
			D<=ADDR;
			if Bupk_Delay_Period/=0 then
				Count_Bytes_After_Delay:=Count_Bytes_After_Delay + 1;
			end if;
		wait until SIR='0';
		AD<='0';
		While ((Count_Bytes_After_Delay=Bupk_Delay_Period and Bupk_Delay_Period/=0) or Count_Delay_Clocks/=0) loop
			if Count_Bytes_After_Delay/=0 then
				nWR<='1';
				wait until SIR='1';
				assert BUSY='0'
				report "Error! Busy MUST be eqal zero in first clock!"
				SEVERITY ERROR;
				Count_Delay_Clocks:=Bupk_Delay_Time-1;
				Count_Bytes_After_Delay:=0;
			else
				nWR<='1';
				Count_Delay_Clocks:=Count_Delay_Clocks-1;
			end if;
			wait until SIR='0';
		end loop;
		nWR<='0';
-- Patched by Gniteev @ 7.10.2005
		if (DATA'Ascending) then
			D<=std_logic_vector(Data(Data'left + Count_Bytes));
		else
			D<=std_logic_vector(Data(Data'right + Count_Bytes));
		end if;		
--		
		Count_Bytes:=Count_Bytes+1;
		if Bupk_Delay_Period/=0 then
			Count_Bytes_After_Delay:=Count_Bytes_After_Delay + 1;
		end if;
		if Bupk_Delay_Period/=1 then
				wait until SIR='1';
				assert BUSY='0'
				report "Error! Busy MUST be eqal zero in first clock!"
				SEVERITY ERROR;
		end if;
		while Count_Bytes/=Length loop
			wait until SIR='0';
			While ((Count_Bytes_After_Delay=Bupk_Delay_Period and Bupk_Delay_Period/=0) or Count_Delay_Clocks/=0) loop
				if Count_Bytes_After_Delay/=0 then
					Count_Delay_Clocks:=Bupk_Delay_Time-1;
					Count_Bytes_After_Delay:=0;
				else
					Count_Delay_Clocks:=Count_Delay_Clocks-1;
				end if;
				nWR<='1';
				wait until SIR='0';
			end loop;
			nWR<='0';
			if (DATA'Ascending) then
				D<=std_logic_vector(Data(Data'left + Count_Bytes));
			else
				D<=std_logic_vector(Data(Data'right + Count_Bytes));
			end if;		

--			D<=std_logic_vector(Data(Data'right - Count_Bytes));
			Count_Bytes:=Count_Bytes+1;
			if Bupk_Delay_Period/=0 then
				Count_Bytes_After_Delay:=Count_Bytes_After_Delay + 1;
			end if;
			wait until SIR='1';
			while BUSY='1' loop
				wait until SIR='1';
			end loop;
		end loop;
		wait until SIR='0';
		nWR<='1';
		wait until SIR='1';
		while BUSY='1' loop
			wait until SIR='1';
		end loop;
		wait until SIR='0';
		D <= (others => 'Z');
		nCS<='1';
		wait until SIR='0';
		wait until SIR='0';
		wait until SIR='0';
	end procedure;
	
	procedure Bupk_Read_RG(
	ADDR		: std_logic_vector(7 downto 0);
	Data		: out slv8_array;
	Length		: integer;
	signal SIR	: in std_logic;
	signal nCS	: out std_logic;
	signal AD	: out std_logic;
	signal nWR	: out std_logic;
	signal nRD	: out std_logic;
	signal D	: inout std_logic_vector(7 downto 0);
	signal Busy	: in STD_LOGIC
	) is
	variable Count_Bytes_After_Delay	: integer:=0;
	variable Count_Delay_Clocks			: integer range 32 downto 0:=0;
	variable Count_Bytes_RD				: integer:=0;
	variable Count_Bytes				: integer:=0;
	variable Last_RD					: std_logic;
	variable INC_RD_Counter_Next_clk	: boolean;
	variable nRD_Int					: std_logic;
	constant Bupk_Delay_Period	: integer range 0 to 512 := 0;
	begin
		wait until SIR='0';
			nCS<='0';
			AD<='1';
			nWR<='0';
			nRD<= not BUPK_new_channel;
			nRD_Int:='0';
			D<=ADDR;
		wait until SIR='0' and SIR'event;
		AD<='0';
		nRD<='0';
		nWR<='1';
		D<=(others=>'Z');
		Count_Bytes_RD:=Count_Bytes_RD+1;
		wait until SIR='1';
		assert BUSY='0'
		report "Error! Busy MUST be eqal zero in first clock!"
		SEVERITY ERROR;
		wait until SIR='0';
--		Count_Bytes_RD:=Count_Bytes_RD+1;
		Last_RD:=nRD_Int;
		if Length/=1 then
			while Count_Bytes_RD/=Length loop
				wait until SIR='1';
				if Busy='0' then
					wait until SIR='0';
					if Last_RD='0' then
-- Patched By Gniteev @ 7.10.2005							   
						if (Data'Ascending) then
							Data(Data'left+Count_Bytes):=D;
						else
							Data(Data'right+Count_Bytes):=D;
						end if;
--
						Count_Bytes:=Count_Bytes+1;
						Count_Bytes_After_Delay:=Count_Bytes_After_Delay+1;
					end if;
					Last_RD:=nRD_Int;
					if ((Count_Bytes_After_Delay=Bupk_Delay_Period and Bupk_Delay_Period/=0) or Count_Delay_Clocks/=0) then
						if Count_Bytes_After_Delay/=0 then
							Count_Delay_Clocks:=Bupk_Delay_Time-1;
							Count_Bytes_After_Delay:=0;
						else
							Count_Delay_Clocks:=Count_Delay_Clocks-1;
						end if;
						nRD<='1';
						nRD_Int:='1';
					else
						nRD<='0';
						nRD_Int:='0';
						Count_Bytes_RD:=Count_Bytes_RD+1;
					end if;
				else
					wait until SIR='0';
					if ((Count_Bytes_After_Delay=Bupk_Delay_Period and Bupk_Delay_Period/=0) or Count_Delay_Clocks/=0) then
						if Count_Bytes_After_Delay/=0 then
							Count_Delay_Clocks:=Bupk_Delay_Time-1;
							Count_Bytes_After_Delay:=0;
						else
							Count_Delay_Clocks:=Count_Delay_Clocks-1;
						end if;
						nRD<='1';
						nRD_Int:='1';
					else
						nRD<='0';
						nRD_Int:='0';
					end if;
				end if;
			end loop;
			nRD<='1';
			nRD_Int:='1';
			wait until SIR='1';
			while BUSY='1' loop
				wait until SIR='0';
				nRD<='1';
				nRD_Int:='1';
				wait until SIR='1';
			end loop;
			wait until SIR='0';
-- Patched By Gniteev @ 7.10.2005							   
			if (Data'Ascending) then
				Data(Data'left+Count_Bytes):=D;
			else
				Data(Data'right+Count_Bytes):=D;
			end if;
-- Patched By Gniteev @ 7.10.2005
			Count_Bytes:=Count_Bytes+1;
			Count_Bytes_After_Delay:=Count_Bytes_After_Delay+1;
			nCS<='1';

			if (Data'Ascending) then
				if Data'Right>(Data'Left+Count_Bytes) then
					Data(Data'left+Count_Bytes to Data'right):=(others=> x"00");
				end if;
			else
				if Data'Left>(Data'right+Count_Bytes) then
					Data(Data'left downto Data'right+Count_Bytes):=(others=> x"00");
				end if;
			end if;
--			
		else
			nRD<='1';
			nRD_Int:='1';
			wait until SIR='1';
			while BUSY='1' loop
				wait until SIR='0';
				nRD<='1';
				nRD_Int:='1';
				wait until SIR='1';
			end loop;
			wait until SIR='0';

			if (Data'Ascending) then
				Data(Data'left+Count_Bytes):=D;
			else
				Data(Data'right+Count_Bytes):=D;
			end if;

--			Data(Data'right-Count_Bytes):=std_logic_vector(7 downto 0)(D);
			Count_Bytes:=Count_Bytes+1;
			Count_Bytes_After_Delay:=Count_Bytes_After_Delay+1;
			nCS<='1';
-- Patched By Gniteev @ 7.10.2005
			if (Data'Ascending) then
				if Data'Right>(Data'Left+Count_Bytes) then
					Data(Data'left+Count_Bytes to Data'right):=(others=> x"00");
				end if;
			else
				if Data'Left>(Data'right+Count_Bytes) then
					Data(Data'left downto Data'right+Count_Bytes):=(others=> x"00");
				end if;
			end if;
--			
		end if;
		wait until SIR='0';
		wait until SIR='0';

	end procedure;
	
	procedure AXI_reset(
		hold_us : natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	) is
		constant OPCODE : std_logic_vector(2 downto 0) := "100";
		variable CMD : std_logic_vector(63 downto 0) := (others => '0');
		variable resetting : std_logic := '0';
		
		variable WDATA : slv8_array(0 to 1024);
		variable RDATA : slv8_array(0 to 1024);
		
		variable start_time : time := 0 ns;
		variable current_time : time := 0 ns;
		constant max_time : time := 10000 ns;
		
	begin
		start_time := now;
		wait until CTRL_CLK = '0';
		CMD(2 downto 0) := OPCODE;
		CMD(31 downto 16) := std_logic_vector(to_unsigned(hold_us, 16));
		WDATA(0 to 7) := slv_to_slv8a(CMD);
		BUPK_WRITE_RG(x"00",WDATA,8,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Запись команды сброса
		
		BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
		resetting := RDATA(0)(3);
		
		while resetting = '1' loop
			current_time := now;
			BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
			assert current_time - start_time < max_time report "Exceeded time register access " & time'image(current_time-start_time) severity FAILURE; --report "Ошибка при проверке регистра " & integer'image(conv_integer(ADDR)) & " с параметром " & integer'image(Loop_Count) severity FAILURE;
			resetting := RDATA(0)(3);
		end loop;		
		
	end procedure AXI_reset;
	
	procedure AXI_wait(
		hold_us : natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	) is
		constant OPCODE : std_logic_vector(2 downto 0) := "010";
		variable CMD : std_logic_vector(63 downto 0) := (others => '0');
		variable waiting : std_logic := '0';
		
		variable WDATA : slv8_array(0 to 1024);
		variable RDATA : slv8_array(0 to 1024);
		
		variable start_time : time := 0 ns;
		variable current_time : time := 0 ns;
		constant max_time : time := 10000 ns;
	begin
		start_time := now;
		wait until CTRL_CLK = '0';
		CMD(2 downto 0) := OPCODE;
		CMD(31 downto 16) := std_logic_vector(to_unsigned(hold_us, 16));
		WDATA(0 to 7) := slv_to_slv8a(CMD);
		BUPK_WRITE_RG(x"00",WDATA,8,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Запись команды ожидания
		
		BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
		waiting := RDATA(0)(3);
		current_time := now;
		
		while waiting = '1' loop
			BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
			assert current_time - start_time < max_time report "Exceeded time register access " & time'image(current_time-start_time) severity FAILURE;
			waiting := RDATA(0)(3);
		end loop;
		
	end procedure AXI_wait;
	
	procedure AXI_state(
		cmd_count : out natural;
		error : out natural;
		last_cmd : out natural;
		last_resp : out natural;
		resetting : out natural;
		waiting : out natural;
		hanged : out natural;
		command_executed : out natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	) is
		variable RDATA : slv8_array(0 to 1024);
		
		variable start_time : time := 0 ns;
		variable current_time : time := 0 ns;
		constant max_time : time := 1000 ns;
	begin
		start_time := now;
		wait until CTRL_CLK = '0';
		current_time := now;
		while current_time - start_time < max_time loop  ---TODO: Возможно нужно изменить условие
			current_time := now;
			BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
			assert current_time - start_time < max_time report " " severity FAILURE;
		end loop;
		cmd_count := to_integer(unsigned(RDATA(2)(7 downto 0)));
		error := to_integer(unsigned(RDATA(1)(7 downto 7)));
		last_cmd := to_integer(unsigned(RDATA(1)(6 downto 4)));
		last_resp := to_integer(unsigned(RDATA(1)(1 downto 0)));
		resetting := to_integer(unsigned(RDATA(0)(3 downto 3)));
		waiting := to_integer(unsigned(RDATA(0)(2 downto 2)));
		hanged := to_integer(unsigned(RDATA(0)(1 downto 1)));
		command_executed := to_integer(unsigned(RDATA(0)(0 downto 0)));
	end procedure AXI_state;
	
	procedure AXI_write(
		addr : natural;
		data : slv8_array;
		size : natural;
		count : natural;
		incr : integer;
		last_resp : out natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
		
	) is
		constant OPCODE : std_logic_vector(2 downto 0) := "001";
		variable CMD : std_logic_vector(63 downto 0) := (others => '0');
		variable command_executed : std_logic := '0';
		variable size_data : natural := 0;
		variable count_data : natural := count - 1;
		
		variable start_time : time := 0 ns;
		variable current_time : time := 0 ns;
		constant max_time : time := 20000 ns;
		
		variable shift : natural := 0;
		variable add_factor : natural := 0;
		variable add_size : natural := 0;
		
		variable WDATA : slv8_array(0 to 1024);
		variable RDATA : slv8_array(0 to 1024);
	begin
		assert size = 1 or size = 2 or size = 4 or size = 8 report "Incorrect size, expected 1, 2 , 4, 8" severity FAILURE;
		assert size * count <= WDATA'right report "Size operation more then expected" severity FAILURE;
		if size = 1 then
			size_data := 0;
		elsif size = 2 then
			size_data := 1;
		elsif size = 4 then
			size_data := 2;
		elsif size = 8 then
			size_data := 3;
		end if;
		CMD(2 downto 0) := OPCODE;
		CMD(7 downto 4) := std_logic_vector(to_unsigned(count_data, 4));
		CMD(9 downto 8) := std_logic_vector(to_unsigned(size_data, 2));
		CMD(10 downto 10) := std_logic_vector(to_unsigned(incr, 1));
		CMD(47 downto 16) := std_logic_vector(to_unsigned(addr, 32));
		WDATA(0 to 7) := slv_to_slv8a(CMD);
		
		wait until CTRL_CLK = '0';
		BUPK_WRITE_RG(x"00",WDATA,8,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Запись команды записи данных
		
		shift := addr rem 4;
		add_factor := (size *count + shift) rem 4;
		report "add_factor " & integer'image(add_factor) severity WARNING;
		report "shift " & integer'image(shift) severity WARNING;
		if shift > 0 then
			WDATA(0 to shift-1) := (others => (others => '0'));
			report "data " & integer'image(to_integer(unsigned(data(0)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(1)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(2)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(3)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(4)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(5)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(6)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(7)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(8)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(9)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(10)))) severity WARNING;
			report "data " & integer'image(to_integer(unsigned(data(11)))) severity WARNING;
			report "count " & integer'image(count) severity WARNING;
			WDATA(shift to shift + size * count - 1) := data(0 to size * count - 1);
		else
			WDATA(0 to size-1) := data(0 to size * count - 1);
		end if;
		if add_factor /= 0 then
			add_size := 4 - add_factor;
			WDATA(shift + (size * count) to shift + (size * count) + add_size-1) := (others => (others => '0'));
		end if;
		
		wait until CTRL_CLK = '0'; 
		report "size " & integer'image(shift + (size * count) + add_size) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(0)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(1)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(2)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(3)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(4)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(5)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(6)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(7)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(8)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(9)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(10)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(WDATA(11)))) severity WARNING;
		BUPK_WRITE_RG(x"01",WDATA,shift + (size * count) + add_size,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Запись данных
		
		BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
		command_executed := RDATA(0)(0);
		
		while command_executed = '1' loop
			current_time := now;
			BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
			assert current_time - start_time < max_time report "Exceeded time register access " & time'image(current_time-start_time) severity FAILURE;
			report "time " & time'image(current_time-start_time) severity WARNING;
			command_executed := RDATA(0)(0);
			last_resp := to_integer(unsigned(RDATA(1)(1 downto 0)));
		end loop;
		wait until CTRL_CLK = '0';
		wait until CTRL_CLK = '0';
		
	end procedure AXI_write;
	
	procedure AXI_read(
		addr : natural;
		data : out slv8_array;
		size : natural;
		count : natural;
		incr : integer;
		last_resp : out natural;
		signal CTRL_CLK : in std_logic;
		signal CTRL_INGRESS  :out std_logic_vector(4 downto 0);
		signal CTRL_EGRESS : in std_logic_vector(0 downto 0);
		signal CTRL_IO : inout std_logic_vector(7 downto 0)
	) is
		constant OPCODE : std_logic_vector(2 downto 0) := "000";
		variable CMD : std_logic_vector(63 downto 0) := (others => '0');
		variable command_executed : std_logic := '0';
		variable size_data : natural := 0;
		variable count_data : natural := count - 1;
		
		variable shift : natural := 0;
		variable add_factor : natural := 0;
		variable add_size : natural := 0;
		
		variable start_time : time := 0 ns;
		variable current_time : time := 0 ns;
		constant max_time : time := 1000 ns;
		
		variable WDATA : slv8_array(0 to 1024);
		variable RDATA : slv8_array(0 to 1024);
	begin
		assert size = 1 or size = 2 or size = 4 or size = 8 report "Incorrect size, expected 1, 2 , 4, 8" severity FAILURE;
		assert size * count <= WDATA'right report "Size operation more then expected" severity FAILURE;
		
		if size = 1 then
			size_data := 0;
		elsif size = 2 then
			size_data := 1;
		elsif size = 4 then
			size_data := 2;
		elsif size = 8 then
			size_data := 3;
		end if;
		
		CMD(2 downto 0) := OPCODE;
		CMD(7 downto 4) := std_logic_vector(to_unsigned(count_data, 4));
		CMD(9 downto 8) := std_logic_vector(to_unsigned(size_data, 2));
		CMD(10 downto 10) := std_logic_vector(to_unsigned(incr, 1));
		CMD(47 downto 16) := std_logic_vector(to_unsigned(addr, 32));
		WDATA(0 to 7) := slv_to_slv8a(CMD);
		
		wait until CTRL_CLK = '0';
		BUPK_WRITE_RG(x"00",WDATA,8,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Запись команды чтения данных
		
		BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
		command_executed := RDATA(0)(0);
		
		while command_executed = '1' loop
			current_time := now;
			BUPK_READ_RG(x"03",RDATA,4,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));  -- Чтение регистра состояния
			assert current_time - start_time < max_time report "Exceeded time register access " & time'image(current_time-start_time) severity FAILURE;
			report "time " & time'image(current_time-start_time) severity WARNING;
			command_executed := RDATA(0)(0);
			last_resp := to_integer(unsigned(RDATA(1)(1 downto 0)));
		end loop;
		
		shift := addr rem 4;
		add_factor := ((size * count) + shift) rem 4;
		if add_factor /= 0 then
			add_size := 4 - add_factor;
		end if;
		
		report "size " & integer'image(shift + (size * count) + add_size) severity WARNING;
		BUPK_READ_RG(x"02",RDATA,shift + (size * count) + add_size,CTRL_CLK,CTRL_INGRESS(0),CTRL_INGRESS(1),CTRL_INGRESS(2),CTRL_INGRESS(3),CTRL_IO,CTRL_EGRESS(0));
		report "data_RG " & integer'image(to_integer(unsigned(RDATA(0)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(RDATA(1)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(RDATA(2)))) severity WARNING;
		report "data_RG " & integer'image(to_integer(unsigned(RDATA(3)))) severity WARNING;
		data(0 to (size * count) - 1):= RDATA(shift to (size * count) - 1);
		
	end procedure AXI_read;
end AXI_API_TO_CC;
