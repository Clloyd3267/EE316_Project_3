--------------------------------------------------------------------------------
-- Filename     : adc_i2c_ut.vhd
-- Author(s)    : Chris Lloyd, Thomas Griebel, Anthony Seybolt
-- Class        : EE316 (Project 3)
-- Due Date     : 2021-03-11
-- Target Board : Cora 7Z010
-- Entity       : adc_i2c_ut
-- Description  : Unit Test (ut) to test I2C ADC interface using clock pulse
--                generator module.
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
entity adc_i2c_ut is
port
(
  I_CLK_125_MHZ  : in std_logic;    -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET        : in std_logic;    -- System reset

  O_PULSE_WAVE   : out std_logic;    -- Clock pulse from waveform gen

  IO_I2C_SDA     : inout std_logic;  -- Serial data of i2c bus
  IO_I2C_SCL     : inout std_logic   -- Serial clock of i2c bus
);
end entity adc_i2c_ut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of adc_i2c_ut is

  ----------------
  -- Components --
  ----------------
  component adc_i2c_driver is
  generic
  (
    C_CLK_FREQ_MHZ : integer := 125                     -- System clock frequency in MHz
  );
  port
  (
    I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N      : in std_logic;                      -- System reset (active low)

    I_ADC_ENABLE   : in std_logic;                      -- Whether the adc is enabled
    I_ADC_CH_NUM   : in std_logic_vector(1 downto 0);   -- The ADC channel number to use
    O_ADC_DATA     : out std_logic_vector(7 downto 0);  -- Data from A/D conversion

    IO_I2C_SDA     : inout std_logic;                   -- Serial data of i2c bus
    IO_I2C_SCL     : inout std_logic                    -- Serial clock of i2c bus
  );
  end component adc_i2c_driver;

  component clk_gen is
  port
  (
    sys_clk     : in std_logic;
    enable      : in std_logic;
    desired_clk : in std_logic_vector(7 downto 0);
    output_clk  : out std_logic
  );
  end component clk_gen;
  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ : integer := 125;  -- System clock frequency in MHz'

  -- ADC channel number to get data from CDL=> List them here
  constant C_ADC_CH_0     : std_logic_vector(1 downto 0) := "00";
  constant C_ADC_CH_1     : std_logic_vector(1 downto 0) := "01";
  constant C_ADC_CH_2     : std_logic_vector(1 downto 0) := "10";
  constant C_ADC_CH_3     : std_logic_vector(1 downto 0) := "11";

  -------------
  -- SIGNALS --
  -------------

  signal s_reset_n        : std_logic;                     -- Active low system reset

  signal s_adc_enable     : std_logic;                     -- Enable signal for ADC module
  signal s_adc_ch_num     : std_logic_vector(1 downto 0);  -- Channel number for ADC module
  signal s_adc_data       : std_logic_vector(7 downto 0);  -- Data from ADC

  signal s_clk_enable     : std_logic;                     -- Enable signal for clk gen module

begin
  ------------------------------
  -- Component Instantiations --
  ------------------------------

  -- Device driver for I2C ADC Converter
  ADC_I2C_DRIVER_INST: adc_i2c_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK          => I_CLK_125_MHZ,
    I_RESET_N      => s_reset_n,

    I_ADC_ENABLE   => s_adc_enable,
    I_ADC_CH_NUM   => s_adc_ch_num,
    O_ADC_DATA     => s_adc_data,

    IO_I2C_SDA     => IO_I2C_SDA,
    IO_I2C_SCL     => IO_I2C_SCL
  );

  -- Device driver for clock pulse generator
  CLOCK_GEN_INST: clk_gen
  port map
  (
    sys_clk     => I_CLK_125_MHZ,
    enable      => s_clk_enable,
    desired_clk => s_adc_data,
    output_clk  => O_PULSE_WAVE
  );

  s_adc_enable <= '1';          -- ADC always enabled
  s_adc_ch_num <= C_ADC_CH_3;   -- ADC channel selection to get data
  s_clk_enable <= '1';          -- CLK gen always enabled

  s_reset_n    <= not I_RESET;  -- Active low reset logic

end architecture behavioral;
