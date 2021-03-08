--------------------------------------------------------------------------------
-- Filename     : i2c_adc_top.vhd
-- Author(s)    : Chris Lloyd, Thomas Griebel, Anthony Seybolt
-- Class        : EE316 (Project 3)
-- Due Date     : 2021-03-11
-- Target Board : Cora 7Z010
-- Entity       : i2c_adc_top
-- Description  : CDL=> Top level entity add description here
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- For edge triggering enum type
library work;
  use work.edge_detector_utilities.all;

--------------
--  Entity  --
--------------
entity i2c_adc_top is
port
(
  I_CLK_125_MHZ       : in std_logic;     -- System clk frequency of (C_CLK_FREQ_MHZ)

  I_BTN_0             : in std_logic;     -- Inputs from onboard buttons
  I_BTN_1             : in std_logic;     -- Inputs from onboard buttons

  -- Onboard RGB Leds:
  -- 0 : LED0B
  -- 1 : LED0G
  -- 2 : LED0R
  -- 3 : LED1B
  -- 4 : LED1G
  -- 5 : LED1R
  O_RGB_LEDS : out std_logic_vector(5 downto 0);

  O_PULSE_WAVE        : out std_logic;    -- Clock pulse from waveform gen
  O_PWM_WAVE          : out std_logic;    -- PWM pulse from pwm gen

  IO_I2C_SDA          : inout std_logic;  -- Serial data of i2c bus
  IO_I2C_SCL          : inout std_logic   -- Serial clock of i2c bus
);
end entity i2c_adc_top;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of i2c_adc_top is

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

  component pwm_driver is
  generic
  (
    C_CLK_FREQ_MHZ : integer := 125                     -- System clock frequency in MHz
  );
  port
  (
    I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N      : in std_logic;                      -- System reset (active low)

    I_PWM_ENABLE   : in std_logic;                      -- Output enable for the module
    I_PWM_DATA     : in std_logic_vector(7 downto 0);   -- Input data to create duty cycle

    O_PWM          : out std_logic                      -- Output PWM waveform
  );
  end component pwm_driver;

  --CDL=> Add LCD components
  --CDL=> Add DAC components (may be included in ADC module)

  component debounce_button is
  generic
  (
    C_CLK_FREQ_MHZ   : integer := 50;  -- System clock frequency in MHz
    C_STABLE_TIME_MS : integer := 10   -- Time required for button to remain stable in ms
  );
  port
  (
    I_CLK            : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N        : in std_logic;  -- System reset (active low)
    I_BUTTON         : in std_logic;  -- Button data to be debounced
    O_BUTTON         : out std_logic  -- Debounced button data
  );
  end component debounce_button;

  component edge_detector is
  generic
  (
    C_CLK_FREQ_MHZ   : integer     := 50;   -- System clock frequency in MHz
    C_TRIGGER_EDGE   : T_EDGE_TYPE := NONE  -- Edge to trigger on
  );
  port
  (
    I_CLK            : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N        : in std_logic;  -- System reset (active low)
    I_SIGNAL         : in std_logic;  -- Input signal to pass through edge detector
    O_EDGE_SIGNAL    : out std_logic  -- Output pulse on (C_TRIGGER_EDGE) edge
  );
  end component edge_detector;

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ  : integer := 125;  -- System clock frequency in MHz

  -- ADC channel number / Data inputs
  constant C_ADC_CH_0      : std_logic_vector(1 downto 0) := "00";  -- LDR
  constant C_ADC_CH_1      : std_logic_vector(1 downto 0) := "01";  -- TEMP
  constant C_ADC_CH_2      : std_logic_vector(1 downto 0) := "10";  -- POT
  constant C_ADC_CH_3      : std_logic_vector(1 downto 0) := "11";  -- ANALOG IN

  -- Data outputs
  constant C_OUT_PWM       : std_logic_vector(1 downto 0) := "00";
  constant C_OUT_CLK       : std_logic_vector(1 downto 0) := "01";
  constant C_OUT_DAC       : std_logic_vector(1 downto 0) := "10";
  constant C_OUT_DISABLED  : std_logic_vector(1 downto 0) := "11";

  constant C_LED_BLUE      : std_logic_vector(2 downto 0) := "001";
  constant C_LED_GREEN     : std_logic_vector(2 downto 0) := "010";
  constant C_LED_RED       : std_logic_vector(2 downto 0) := "100";
  constant C_LED_OFF       : std_logic_vector(2 downto 0) := "000";

  -- Inital System reset time in ms
  constant C_RESET_TIME_MS : integer := 25;

  -------------
  -- SIGNALS --
  -------------

  signal s_reset_n         : std_logic;                     -- Active low system reset

  signal s_adc_enable      : std_logic;                     -- Enable signal for ADC module
  signal s_adc_ch_num      : std_logic_vector(1 downto 0);  -- Channel number for ADC module
  signal s_adc_data        : std_logic_vector(7 downto 0);  -- Data from ADC

  signal s_clk_enable      : std_logic;                     -- Enable signal for CLK gen module
  signal s_pwm_enable      : std_logic;                     -- Enable signal for PWM gen module
  signal s_dac_enable      : std_logic;                     -- Enable signal for DAC gen module

  signal s_output_mode     : std_logic_vector(1 downto 0);  -- Data output mode

  signal s_led_0           : std_logic_vector(2 downto 0);  -- LED0 output
  signal s_led_1           : std_logic_vector(2 downto 0);  -- LED1 output

  signal s_debounced_btn_0 : std_logic;                     -- Debounced BTN0 signal
  signal s_debounced_btn_1 : std_logic;                     -- Debounced BTN1 signal

  signal s_edge_trig_btn_0 : std_logic;                     -- Edge triggered BTN0 signal
  signal s_edge_trig_btn_1 : std_logic;                     -- Edge triggered BTN1 signal

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

  -- Device driver for PWM generator
  PWM_GEN_INST: pwm_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK          => I_CLK_125_MHZ,
    I_RESET_N      => s_reset_n,
    I_PWM_ENABLE   => s_pwm_enable,
    I_PWM_DATA     => s_adc_data,
    O_PWM          => O_PWM_WAVE
  );

  --CDL=> Add LCD component instantions
  --CDL=> Add DAC component instantions (may be included in ADC module)

  -- Device driver for BTN0 debounce module
  DEBOUNCE_BTN0_INST: debounce_button
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK          => I_CLK_125_MHZ,
    I_RESET_N      => s_reset_n,
    I_BUTTON       => I_BTN_0,
    O_BUTTON       => s_debounced_btn_0
  )

  -- Device driver for BTN1 debounce module
  DEBOUNCE_BTN1_INST: debounce_button
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK          => I_CLK_125_MHZ,
    I_RESET_N      => s_reset_n,
    I_BUTTON       => I_BTN_1,
    O_BUTTON       => s_debounced_btn_1
  )

  -- Device driver for BTN0 edge trigger module
  EDGE_TRIG_BTN0_INST: edge_detector
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ,
    C_TRIGGER_EDGE => RISING
  )
  port map
  (
    I_CLK          => I_CLK_125_MHZ,
    I_RESET_N      => s_reset_n,
    I_SIGNAL       => s_debounced_btn_0,
    O_EDGE_SIGNAL  => s_edge_trig_btn_0
  )

  -- Device driver for BTN1 edge trigger module
  EDGE_TRIG_BTN1_INST: edge_detector
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ,
    C_TRIGGER_EDGE => RISING
  )
  port map
  (
    I_CLK          => I_CLK_125_MHZ,
    I_RESET_N      => s_reset_n,
    I_SIGNAL       => s_debounced_btn_1,
    O_EDGE_SIGNAL  => s_edge_trig_btn_1
  )

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : SYSTEM_RST_OUTPUT
  -- Sensitivity List : I_CLK_125_MHZ : System clock
  -- Useful Outputs   : s_reset_n     : Reset signal from counter (active low)
  -- Description      : System FW Reset Output logic (active low reset logic).
  --                    Holding design in reset for (C_RESET_TIME_MS) ms.
  ------------------------------------------------------------------------------
  SYSTEM_RST_OUTPUT: process (I_CLK_125_MHZ)
    variable C_RST_MS_DURATION : integer := C_CLK_FREQ_MHZ * C_RESET_TIME_MS * 1000;
    variable v_reset_cntr      : integer range 0 TO C_RST_MS_DURATION := 0;
  begin
    if (rising_edge(I_CLK_125_MHZ)) then
      if (v_reset_cntr = C_RST_MS_DURATION) then
        v_reset_cntr := v_reset_cntr;
        s_reset_n    <= '1';
      else
        v_reset_cntr := v_reset_cntr + 1;
        s_reset_n    <= '0';
      end if;
    end if;
  end process SYSTEM_RST_OUTPUT;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : INOUT_MODE_CONTROL
  -- Sensitivity List : I_CLK_125_MHZ : System clock
  --                    s_reset_n     : System reset (active low)
  -- Useful Outputs   : s_adc_ch_num  : Input channel mode from ADC.
  --                    s_output_mode : Output mode to write data to.
  -- Description      : A process to control the input and output mode of the
  --                    system.
  ------------------------------------------------------------------------------
  INOUT_MODE_CONTROL: process (I_CLK_125_MHZ)
  begin
    if (s_reset_n = '0') then
      s_adc_ch_num        <= C_ADC_CH_3;  -- Default values for input mode
      s_output_mode       <= C_OUT_CLK;   -- Default values for output mode

    elsif (rising_edge(I_CLK_125_MHZ)) then

      if (s_edge_trig_btn_1 = '1') then
        -- Toggle input mode
        case (s_adc_ch_num) is
          when C_ADC_CH_0 =>
            s_adc_ch_num  <= C_ADC_CH_1;
          when C_ADC_CH_1 =>
            s_adc_ch_num  <= C_ADC_CH_2;
          when C_ADC_CH_2 =>
            s_adc_ch_num  <= C_ADC_CH_3;
          when C_ADC_CH_3 =>
            s_adc_ch_num  <= C_ADC_CH_0;
          when others =>
            s_adc_ch_num  <= C_ADC_CH_0;
        end case;
      else
        s_adc_ch_num      <= s_adc_ch_num;
      end if;

      if (s_edge_trig_btn_0 = '1') then
        -- Toggle output mode
        case (s_output_mode) is
          when C_OUT_PWM =>
            s_output_mode <= C_OUT_CLK;
          when C_OUT_CLK =>
            s_output_mode <= C_OUT_DAC;
          when C_OUT_DAC =>
            s_output_mode <= C_OUT_DISABLED;
          when C_OUT_DISABLED =>
            s_output_mode <= C_OUT_PWM;
          when others =>
            s_output_mode <= C_OUT_DISABLED;
        end case;
      else
        s_output_mode     <= s_output_mode;
      end if;
    end if;
  end process INOUT_MODE_CONTROL;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : DATA_FLOW_CTRL
  -- Sensitivity List : I_CLK_125_MHZ : System clock
  --                    s_reset_n     : System reset (active low)
  -- Useful Outputs   : s_pwm_enable  : Enable signal for PWM module
  --                  : s_clk_enable  : Enable signal for CLK module
  --                  : s_dac_enable  : Enable signal for DAC module
  --                  : s_led_0       : LED0 output
  --                  : s_led_1       : LED1 output
  -- Description      : A process to control the input and output data of the
  --                    system.
  ------------------------------------------------------------------------------
  DATA_FLOW_CTRL: process (I_CLK_125_MHZ)
  begin
    if (s_reset_n = '0') then
      s_pwm_enable   <= '0';
      s_clk_enable   <= '0';
      s_dac_enable   <= '0';
      s_led_0        <= C_LED_OFF;
      s_led_1        <= C_LED_OFF;

    elsif (rising_edge(I_CLK_125_MHZ)) then

      -- Control PWM output enable
      if (s_output_mode = C_OUT_PWM) then
        s_pwm_enable <= '1';
      else
        s_pwm_enable <= '0';
      end if;

      -- Control CLK output enable
      if (s_output_mode = C_OUT_CLK) then
        s_clk_enable <= '1';
      else
        s_clk_enable <= '0';
      end if;

      -- Control DAC output enable
      if (s_output_mode = C_OUT_DAC) then
        s_dac_enable <= '1';
      else
        s_dac_enable <= '0';
      end if;

      -- Input LED control
      case (s_adc_ch_num) is
        when C_ADC_CH_0 =>
          s_led_1 <= C_LED_BLUE;
        when C_ADC_CH_1 =>
          s_led_1 <= C_LED_RED;
        when C_ADC_CH_2 =>
          s_led_1 <= C_LED_GREEN;
        when C_ADC_CH_3 =>
          s_led_1 <= C_LED_OFF;
        when others =>
          s_led_1 <= C_LED_OFF;
      end case;

      -- Output LED control
      case (s_output_mode) is
        when C_OUT_PWM =>
          s_led_0 <= C_LED_BLUE;
        when C_OUT_CLK =>
          s_led_0 <= C_LED_RED;
        when C_OUT_DAC =>
          s_led_0 <= C_LED_GREEN;
        when C_OUT_DISABLED =>
          s_led_0 <= C_LED_OFF;
        when others =>
          s_led_0 <= C_LED_OFF;
      end case;
    end if;
  end process DATA_FLOW_CTRL;
  ------------------------------------------------------------------------------

  s_adc_enable <= '1';                -- ADC always enabled
  O_RGB_LEDS   <= s_led_1 & s_led_0;  -- Combine LED outputs

end architecture behavioral;
