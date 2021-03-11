LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

library work;
	use work.lcd_screen_util.all;
	
entity usr_logic is
port(	clk : 	 in std_logic;
		--iData:   in t_lcd_display_data;
        I_MODE         : in std_logic_vector(1 downto 0) := "00";
  
        -- Clock Generation En
        CLK_GEN_EN	 : in std_logic := '1';
		oSDA: 	 inout Std_logic;
		oSCL:	 inout std_logic);

end usr_logic;

architecture behavior of usr_logic is

--signal Cont 		: unsigned(19 downto 0) := X"1C9C37"; --15ms delay at start
signal Cont : integer := 1874999;

type state_type is (start, pause, write_data, repeat);
signal state : state_type := start;

--signal slave_addr : std_logic_vector(6 downto 0) := "0100111"; -- Not Needed
signal i2c_addr : std_logic_vector(6 downto 0);
signal regBusy, sigBusy, reset_n, i2c_ena, i2c_rw, ack_err : std_logic;
signal data_wr: std_logic_vector(7 downto 0) := (others => '0');
-- signal i2c_data_wr : std_logic_vector(7 downto 0); -- THIS IS NOT EVEN BEING USED
signal byteSel : integer := 0;
signal initSel : integer := 0;
signal lcd_pos : integer := 31;
signal init_cont : integer := 1000;
signal regData: t_lcd_display_data;
signal busy_prev : std_logic;
signal init_lcd : std_logic := '1';
signal iData:   t_lcd_display_data;

component i2c_master is
GENERIC(
    input_clk : INTEGER := 125_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 100_000);   --speed the i2c bus (scl) will run at in Hz
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
    I_CLK          : in std_logic ;
    I_MODE         : in std_logic_vector(1 downto 0);
    CLK_GEN_EN     : in std_logic;
    I_RESET_N      : in std_logic;   
    O_LCD_DATA     : out t_lcd_display_data
);
end component lut;
begin


inst_master : i2c_master
generic map(
  input_clk => 125_000_000,
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
    I_CLK => clk,
    I_MODE => I_MODE,
    CLK_GEN_EN => CLK_GEN_EN,
    I_RESET_N => reset_n,
    O_LCD_DATA => iData
);

-- CMD_COUNT : process(clk)
--  begin
--    if (reset_n = '1') then
--      Cont <=  0;
--    elsif (rising_edge(clk)) then
         
--      if (state = write_data) then
--        if (Cont /= 0) then
--          Cont <= Cont -1;
--        else
--          Cont <= 624999;
--        end if;
--      end if;
--    end if;
--  end process;

process(clk)
begin
if(rising_edge(clk)) then
	regData <= iData;
	regBusy <= sigBusy;
	case state is
		when start =>
			--if Cont /= X"000000" then
			if Cont /= 0 then
				Cont <= Cont -1;
				reset_n <= '0';
				state <= start;
				i2c_ena <= '0';
			else
				reset_n <= '1';
				i2c_ena <= '1';
				i2c_addr <= "0100111";
				i2c_rw <= '0';
				-- data_wr <= i2c_data_wr; -- This line really doesn't do anything
				state <= write_data;
			end if;
		when write_data =>

		if regBusy/=sigBusy and sigBusy='0' then
			
			if init_lcd = '1'  then
--			     if byteSel = 2 or byteSel = 5 then
--                       i2c_ena <= '0';
--                       state <= pause;
                        
		      --   elsif byteSel /= 47 and byteSel /=2 and byteSel /= 5 then  
			     if byteSel /= 47 then
			     
			     byteSel <= byteSel + 1;
--			     state <= write_data;
			    -- else
			         --byteSel <= 0;
			        -- i2c_ena <= '0';
--			         state <= repeat;
			         --init_lcd <= '1';
			     else
			         byteSel <= 0;
			         init_lcd <= '0';
			         
	               end if;
		 --    end if;
			else 
			     
			if byteSel /= 11 then
				byteSel <= byteSel + 1;
--				state <= write_data;
            else
                
                if lcd_pos = 0 then
--                   lcd_pos <= 31;
--                   byteSel <= 0;
                     
--                elsif lcd_pos = 16 then
--                    lcd_pos <= 16;
                else
                    lcd_pos <= lcd_pos - 1;
                    byteSel <= 0;
            
                end if;

           
			
			end if;
			end if;
           i2c_ena <= '0';			
		   state <= pause;
		   init_cont <= 5000;			
		end if;
		when repeat => -- wait for new data
			i2c_ena <= '0';
			if regData /= iData then
				Cont <= 624999;
				state <= start;
			else
				state <= repeat;
			end if;
			
		when pause =>
		  
		  if init_cont /= 0 then
		              
		              init_cont <= init_cont - 1;
                  else
--		              init_cont <= 1000;
                      i2c_ena <= '1';
--                      byteSel <= byteSel + 1;
                      state <= write_data;
--		              Cont <= 100; --624999;
--		              byteSel <= byteSel + 1;
--		              state <= start;
                   end if;
		end case;
end if;
end process;

process(byteSel)
begin

if init_lcd = '0' then
	case byteSel is
	
	   
--	    when 0 => data_wr <= iData(lcd_pos)(7 downto 4)&"1001";
--		when 1 => data_wr <= iData(lcd_pos)(7 downto 4)&"1101";
--		when 2 => data_wr <= iData(lcd_pos)(7 downto 4)&"1001";
		when 3 => data_wr <= iData(lcd_pos)(3 downto 0)&"1001";
		when 4 => data_wr <= iData(lcd_pos)(3 downto 0)&"1101";
		when 5 => data_wr <= iData(lcd_pos)(3 downto 0)&"1001";
        when 6 => 
		  if lcd_pos = 16 then
		          data_wr <= X"C"&"1000";
		  end if;
		  
		when 7 => 
		  if lcd_pos = 16 then
		          data_wr <= X"C"&"1100";
		  end if;
		  
		when 8 => 
		  if lcd_pos = 16 then
		          data_wr <= X"C"&"1000";
		  end if;
		  
		when 9 => 
		  if lcd_pos = 16 then
		          data_wr <= X"0"&"1100";
		  end if;
		  
		when 10 => 
		  if lcd_pos = 16 then
		          data_wr <= X"0"&"1100";
		  end if;
		  
		when 11 => 
		  if lcd_pos = 16 then
		          data_wr <= X"0"&"1100";
		  end if;
		  
		when others => data_wr <= "00001001";
end case;
		
else
	case byteSel is
	    when 0 => data_wr <= X"0"&"1000";
	    when 1 => data_wr <= X"0"&"1100";
	    when 2 => data_wr <= X"0"&"1000";
	    
	    when 3 => data_wr <= X"1"&"1000";
	    when 4 => data_wr <= X"1"&"1100";
	    when 5 => data_wr <= X"1"&"1000";
	    
		when 6 => data_wr <= "0011"&"1000";
		when 7 => data_wr <= "0011"&"1100";
		when 8 => data_wr <= "0011"&"1000";
--               i2c_ena <= '0';
--               state <= pause;
		when 9 => data_wr <= "0011"&"1000";
		when 10 => data_wr <= "0011"&"1100";
		when 11 => data_wr <= "0011"&"1000";
		  	--wait for 100us;
--		if init_cont /= 0 then
--		              init_cont <= init_cont - 1;
--                  else
--		              init_cont <= 624999;
--		          end if
--		          ;
		when 12 => data_wr <= "0011"&"1000";
		when 13 => data_wr <= "0011"&"1100";
		when 14 => data_wr <= "0011"&"1000";
		--check not busy
		when 15 => data_wr <= "0010"&"1000";
		when 16 => data_wr <= "0010"&"1100";
		when 17 => data_wr <= "0010"&"1000";
		
		when 18 => data_wr <= "0010"&"1000";
		when 19 => data_wr <= "0010"&"1100";
		when 20 => data_wr <= "0010"&"1000";
		--check for not busy
		when 21 => data_wr <= "1100"&"1000";
		when 22 => data_wr <= "1100"&"1100";
		when 23 => data_wr <= "1100"&"1000";
		--check for not busy
		when 24 => data_wr <= "0000"&"1000";
		when 25 => data_wr <= "0000"&"1100";
		when 26 => data_wr <= "0000"&"1000";
		
		when 27 => data_wr <= "1000"&"1000";
		when 28 => data_wr <= "1000"&"1100";
		when 29 => data_wr <= "1000"&"1000";
		--check for not busy
		when 30 => data_wr <= "0000"&"1000";
		when 31 => data_wr <= "0000"&"1100";
		when 32 => data_wr <= "0000"&"1000";
		
		when 33 => data_wr <= "0001"&"1000";
		when 34 => data_wr <= "0001"&"1100";
		when 35 => data_wr <= "0001"&"1000";
		--check for not busy
		when 36 => data_wr <= "0000"&"1000";
		when 37 => data_wr <= "0000"&"1100";
		when 38 => data_wr <= "0000"&"1000";
		
		when 39 => data_wr <= "0011"&"1000";
		when 40 => data_wr <= "0011"&"1100";
		when 41 => data_wr <= "0011"&"1000";
		
		when 42 => data_wr <= "0000"&"1000";
		when 43 => data_wr <= "0000"&"1100";
		when 44 => data_wr <= "0000"&"1000";
		
		when 45 => data_wr <= "1111"&"1000";
		when 46 => data_wr <= "1111"&"1100";
		when 47 => data_wr <= "1111"&"1000";
		--end of initialization
		
--		when 42 => data_wr <= "0100"&"1001";
--		when 43 => data_wr <= "0100"&"1101";
--		when 44 => data_wr <= "0100"&"1001";
		
--		when 45 => data_wr <= "0001"&"1001";
--		when 46 => data_wr <= "0001"&"1101";
--		when 47 => data_wr <= "0001"&"1001";
		
		when others => data_wr <= "00000000";
	
	end case;
	end if;
end process;



end behavior;
