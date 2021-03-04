LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

library work;
	use work.lcd_screen_util.all;
	
entity usr_logic is
port(	clk : 	 in std_logic;
		--iData:   in t_lcd_display_data;

		oSDA: 	 inout Std_logic;
		oSCL:	 inout std_logic);

end usr_logic;

architecture behavior of usr_logic is

signal Cont 		: unsigned(19 downto 0) := X"03FFF";

type state_type is (start, write_data, repeat);
signal state : state_type := start;

-- signal slave_addr : std_logic_vector(6 downto 0) := "1110001"; -- Not Needed
signal i2c_addr : std_logic_vector(6 downto 0);
signal regBusy, sigBusy, reset_n, i2c_ena, i2c_rw, ack_err : std_logic;
signal data_wr: std_logic_vector(7 downto 0);
-- signal i2c_data_wr : std_logic_vector(7 downto 0); -- THIS IS NOT EVEN BEING USED
signal byteSel : integer := 0;
signal initSel : integer := 0;
signal lcd_pos : integer := 0;

signal regData: t_lcd_display_data;
signal busy_prev : std_logic;
signal init_lcd : std_logic := '1';
signal iData:   t_lcd_display_data;
component i2c_master is
GENERIC(
    input_clk : INTEGER := 100_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
END component i2c_master;

component lut is 
port(
    O_LCD_DATA     : out t_lcd_display_data
);
end component lut;
begin


inst_master : i2c_master
generic map(
  input_clk => 50_000_000,
  bus_clk   => 100_000
)
port map(
	clk => clk,
	reset_n => reset_n,
	ena => i2c_ena,
	addr => i2c_addr,
	rw => i2c_rw,
	data_wr => data_wr,
	busy => sigBusy,
	data_rd => OPEN,      -- WHATS THIS?
	ack_error => ack_err,
	sda => oSDA,
	scl => oSCL);
	
inst_lut : lut
port map(
    O_LCD_DATA => iData
);

process(clk)
begin
if(rising_edge(clk)) then
	regData <= iData;
	regBusy <= sigBusy;
	case state is
		when start =>
			if Cont /= X"00000" then
				Cont <= Cont -1;
				reset_n <= '0';
				state <= start;
				i2c_ena <= '0';
			else
				reset_n <= '1';
				i2c_ena <= '1';
				i2c_addr <= "1110001";
				i2c_rw <= '0';
				-- data_wr <= i2c_data_wr; -- This line really doesn't do anything
				state <= write_data;
			end if;
		when write_data =>
		if regBusy/=sigBusy and sigBusy='0' then
			
			if init_lcd = '1'  then
			     if byteSel /= 17 then
			     
			     byteSel <= byteSel + 1;
			     state <= write_data;
			     else 
			         byteSel <=0;
			         i2c_ena <= '0';
			         state <= repeat;
			         init_lcd <= '0';
			     end if;
			else 
			     
			if lcd_pos /= 31 then
			
			
			if byteSel /= 11 then
				byteSel <= byteSel + 1;
				state <= write_data;
			else
				byteSel <= 0;
				i2c_ena <= '0';
				lcd_pos <= lcd_pos + 1;
				state <= repeat;
			end if;
			end if;
			end if;
		end if;
		when repeat => -- wait for new data
			i2c_ena <= '0';
			if regData /= iData then
				Cont <= X"03FFF";
				state <= start;
			else
				state <= repeat;
			end if;
		end case;
end if;
end process;

process(byteSel)
begin

if init_lcd = '0' then
	case byteSel is
	
	   
	    when 0 => data_wr <= iData(lcd_pos)(7 downto 4)&"0001";
		when 1 => data_wr <= iData(lcd_pos)(7 downto 4)&"0101";
		when 2 => data_wr <= iData(lcd_pos)(7 downto 4)&"0001";
		when 3 => data_wr <= iData(lcd_pos)(3 downto 0)&"0001";
		when 4 => data_wr <= iData(lcd_pos)(3 downto 0)&"0101";
		when 5 => data_wr <= iData(lcd_pos)(3 downto 0)&"0001";
		when 6 => data_wr <= X"1"&"0001";
		when 7 => data_wr <= X"1"&"0101";
		when 8 => data_wr <= X"1"&"0001";
		when 9 => data_wr <= X"4"&"0001";
		when 10 => data_wr <= X"4"&"0101";
		when 11 => data_wr <= X"4"&"0001"; 
		when others => data_wr <= "00000001";
end case;
		
	   else
		case byteSel is
		when 0 => data_wr <= X"2"&"0001";
		when 1 => data_wr <= X"2"&"0001";
		when 2 => data_wr <= X"2"&"0001";
		when 3 => data_wr <= X"8"&"0001";
		when 4 => data_wr <= X"8"&"0001";
		when 5 => data_wr <= X"8"&"0001";
		when 6 => data_wr <= X"0"&"0001";
		when 7 => data_wr <= X"0"&"0101";
		when 8 => data_wr <= X"0"&"0001";
		when 9 => data_wr <= X"1"&"0001";
		when 10 => data_wr <= X"1"&"0101";
		when 11 => data_wr <= X"1"&"0001";
		when 12 => data_wr <= X"0"&"0001";
		when 13 => data_wr <= X"0"&"0101";
		when 14 => data_wr <= X"0"&"0001";
		when 15 => data_wr <= X"C"&"0001";
		when 16 => data_wr <= X"C"&"0101";
		when 17 => data_wr <= X"C"&"0001";
		when others => data_wr <= "00000001";
	
	end case;
	end if;
end process;



end behavior;
