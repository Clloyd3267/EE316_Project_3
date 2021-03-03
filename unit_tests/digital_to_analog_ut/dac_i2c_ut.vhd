--------------------------------------------------------------------------------
-- Filename     : dac_i2c_ut.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 2)
-- Due Date     : 2021-02-23
-- Target Board : Altera DE2 Devkit
-- Entity       : keypad_display_ut
-- Description  : Unit Test (ut) to test I2C Seven Segment Display using an
--                external matrix keypad.
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------
--  Entity  --
--------------
entity dac_i2c_ut is
port
(
  I_CLK_125_MHZ  : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET      : in std_logic;                      -- System reset (active low)
  I_BTN_1        : in std_logic;
  IO_I2C_SDA     : inout std_logic;                   -- Serial data of i2c bus
  IO_I2C_SCL     : inout std_logic                    -- Serial clock of i2c bus
);
end entity dac_i2c_ut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of dac_i2c_ut is

  ----------------
  -- Components --
  ----------------

  component dac_i2c_driver is
  generic
  (
    C_CLK_FREQ_MHZ : integer := 125                     -- System clock frequency in MHz
  );
  port
  (
    I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N      : in std_logic;                      -- System reset (active low)
  
    I_DAC_ENABLE   : in std_logic;                      -- Whether the screen is on '1' or off '0'
  
    I_DAC_DATA     : in std_logic_vector(7 downto 0);   -- Data to generate Digital to analog output
    O_BUSY         : out std_logic;                     -- Busy signal from I2C master
  
    IO_I2C_SDA     : inout std_logic;                   -- Serial data of i2c bus
    IO_I2C_SCL     : inout std_logic                    -- Serial clock of i2c bus
  );
  end component dac_i2c_driver;

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ : integer := 125;  -- System clock frequency in MHz

  -------------
  -- SIGNALS --
  -------------

  signal s_reset_n       : std_logic;                      -- Busy signal from I2C 7SD
  signal s_dac_busy        : std_logic; 
  signal s_dac_en        : std_logic; 
  signal s_dac_data      : std_logic_vector(7 downto 0);
  signal s_ascending     : std_logic;
  signal s_address_toggle : std_logic;

begin

  -- Device driver for 7SD
  dac_driver: dac_i2c_driver
  generic map
  (
    C_CLK_FREQ_MHZ   => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK_125_MHZ,
    I_RESET_N        => s_reset_n,
    
    I_DAC_ENABLE    => s_dac_en, 
    I_DAC_DATA      => s_dac_data,
    O_BUSY           => s_dac_busy,
    IO_I2C_SDA       => IO_I2C_SDA,
    IO_I2C_SCL       => IO_I2C_SCL
    );

  ---------------
  -- Processes --
  ---------------


  ------------------------------------------------------------------------------
  ADDRESS_TOGGLE_COUNTER: process (I_CLK_125_MHZ, s_reset_n)
    constant C_11_KHZ_MAX_COUNT    : integer := C_CLK_FREQ_MHZ * 500;  -- 11.1 kHz: 91
    variable v_address_toggle_cntr : integer range 0 to C_11_KHZ_MAX_COUNT := 0;
  begin
    if (s_reset_n = '0') then
      v_address_toggle_cntr     :=  0;
      s_address_toggle          <= '0';

    elsif (rising_edge(I_CLK_125_MHZ)) then
      if (v_address_toggle_cntr /= C_11_KHZ_MAX_COUNT) then
        v_address_toggle_cntr := v_address_toggle_cntr + 1;
      else
        v_address_toggle_cntr := 0;
      end if;

      if (v_address_toggle_cntr /= C_11_KHZ_MAX_COUNT) then
        s_address_toggle          <= '0';
      else
        s_address_toggle          <= '1';
      end if;      
    end if;
  end process ADDRESS_TOGGLE_COUNTER;
  ------------------------------------------------------------------------------  

  ------------------------------------------------------------------------------
  -- Process Name     : KEYPAD_DISPLAY_TEST
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   :
  -- Description      : A process to latch triggered inputs from a matrix
  --                    keypad
  ------------------------------------------------------------------------------
  KEYPAD_DISPLAY_TEST: process (I_CLK_125_MHZ, s_reset_n)
  variable v_index : unsigned(7 downto 0) := (others=>'0');
  begin
    if (s_reset_n = '0') then
      s_dac_data <= (others=>'1');
      s_dac_en <= '0';
      v_index := (others=>'0');
      s_ascending <= '1';

    elsif (rising_edge(I_CLK_125_MHZ)) then
      s_dac_en <= '1';
--      if (I_BTN_1 = '0') then
--        s_dac_data <= s_dac_data;
--      else
--        s_dac_data <= std_logic_vector(v_index);
--      end if;
       s_dac_data <= std_logic_vector(v_index);
--      s_dac_data <= "11111111";
        if (s_dac_busy = '0' and s_address_toggle = '1') then    
            if (v_index < 256) then
                v_index := v_index + 1;
--            else
--                v_index := (others=> '0');
            end if;
--        else
--          v_index := v_index;
        end if;
    --      if (s_dac_busy = '0' and s_address_toggle = '1') then
--        if (s_ascending = '1') then
--            if (v_index < 256) then
--                v_index := v_index + 1;
--            else
--                s_ascending <= '0';
--            end if;
--         else
--            if (v_index >= 0) then
--                v_index := v_index - 1;
--            else
--                s_ascending <= '1';
--            end if;         
--         end if;
--      end if;
    end if;
  end process KEYPAD_DISPLAY_TEST;
  ------------------------------------------------------------------------------

s_reset_n <= not I_RESET;
end architecture behavioral;
