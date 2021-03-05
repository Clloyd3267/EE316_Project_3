--------------------------------------------------------------------------------
-- Filename     : adc_i2c_driver.vhd
-- Author(s)    : Chris Lloyd, Thomas Griebel, Anthony Seybolt
-- Class        : EE316 (Project 3)
-- Due Date     : 2021-03-11
-- Target Board : Cora 7Z010
-- Entity       : adc_i2c_driver
-- Description  : Module to get analog data from a PCF8591T I2C A/D and D/A
--                converter.
--                CDL=> Add more here
--                https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324
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
entity adc_i2c_driver is
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
end entity adc_i2c_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of adc_i2c_driver is

  ----------------
  -- Components --
  ----------------
  component i2c_master is
  generic
  (
    input_clk : integer := 125_000_000;              -- Input clock speed from user logic in Hz
    bus_clk   : integer := 100_000                   -- Speed the i2c bus (scl) will run at in Hz
  );
  port
  (
    clk       : in     std_logic;                    -- System clock
    reset_n   : in     std_logic;                    -- Active low reset
    ena       : in     std_logic;                    -- Latch in command
    addr      : in     std_logic_vector(6 downto 0); -- Address of target slave
    rw        : in     std_logic;                    -- '0' is write, '1' is read
    data_wr   : in     std_logic_vector(7 downto 0); -- Data to write to slave
    busy      : out    std_logic;                    -- Indicates transaction in progress
    data_rd   : out    std_logic_vector(7 downto 0); -- Data read from slave
    ack_error : buffer std_logic;                    -- Flag if improper acknowledge from slave
    sda       : inout  std_logic;                    -- Serial data output of i2c bus
    scl       : inout  std_logic                     -- Serial clock output of i2c bus
  );
  end component i2c_master;

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_HZ         : integer := C_CLK_FREQ_MHZ * 1_000_000;
  constant C_I2C_BUS_CLK_FREQ_HZ : integer := 100_000;

  constant C_I2C_ADC_ADDR        : std_logic_vector(7 downto 0) := x"48";  -- CDL=> May need to be "0x48"

  -------------
  -- SIGNALS --
  -------------

  -- State machine related signals
  type T_DAC_STATE is (WRITE_CONTROL_STATE, READ_ANALOG_STATE, WAIT_STATE);
  signal s_i2c_curr_state       : T_DAC_STATE := WAIT_STATE;

  signal s_i2c_enable           : std_logic;
  signal s_i2c_address          : std_logic_vector(6 downto 0) := C_I2C_ADC_ADDR(6 downto 0);
  signal s_i2c_rw               : std_logic;  --'0' is write, '1' is read
  signal s_wr_data_byte         : std_logic_vector(7 downto 0);
  signal s_rw_data_byte         : std_logic_vector(7 downto 0);
  signal s_i2c_busy             : std_logic;
  signal s_i2c_busy_prev        : std_logic;
  signal s_adc_ch_num_prev      : std_logic_vector(1 downto 0);

begin
  ------------------------------
  -- Component Instantiations --
  ------------------------------

  -- I2C controller for ADC
  I2C_MASTER_INST:i2c_master
  generic map
  (
    input_clk => C_CLK_FREQ_HZ,
    bus_clk   => C_I2C_BUS_CLK_FREQ_HZ
  )
  port map
  (
    clk       => I_CLK,
    reset_n   => I_RESET_N,
    ena       => s_i2c_enable,
    addr      => s_i2c_address,
    rw        => s_i2c_rw,
    data_wr   => s_wr_data_byte,
    busy      => s_i2c_busy,
    data_rd   => s_rw_data_byte,
    ack_error => open,
    sda       => IO_I2C_SDA,
    scl       => IO_I2C_SCL
  );

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : I2C_STATE_MACHINE
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_i2c_curr_state : The current state of the system
  -- Description      : State machine process to control the ADC I2C master.
  ------------------------------------------------------------------------------
  I2C_STATE_MACHINE: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_i2c_curr_state         <= WAIT_STATE;

    elsif (rising_edge(I_CLK)) then
      if (I_ADC_ENABLE = '0') then
        s_i2c_curr_state       <= WAIT_STATE;
      else
        -- I2C state machine logic
        case s_i2c_curr_state is
          -- Transition state to wait for I2C to be no longer busy
          when WAIT_STATE =>
            if (s_i2c_busy = '0') then
              s_i2c_curr_state <= WRITE_CONTROL_STATE;
            else
              s_i2c_curr_state <= WAIT_STATE;
            end if;

          -- Write the control byte indicating what channel to use
          when WRITE_CONTROL_STATE =>
          if ((s_i2c_busy_prev = '0') and (s_i2c_busy = '1')) then
            s_i2c_curr_state   <= READ_ANALOG_STATE;
          else
            s_i2c_curr_state   <= WRITE_CONTROL_STATE;
          end if;

          -- Contiously read values from the ADC until a new channel is selected
          when READ_ANALOG_STATE =>
            if (s_adc_ch_num_prev /= I_ADC_CH_NUM) then
              s_i2c_curr_state <= WAIT_STATE;
            else
              s_i2c_curr_state <= READ_ANALOG_STATE;
            end if;

          -- Error condition, should never occur
          when others =>
            s_i2c_curr_state   <= WAIT_STATE;
        end case;
      end if;
    end if;
  end process I2C_STATE_MACHINE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : DATA_FLOW_CTRL
  -- Sensitivity List : I_CLK             : System clock
  --                    I_RESET_N         : System reset (active low logic)
  -- Useful Outputs   : s_i2c_busy_prev   : Previous busy signal value.
  --                    s_adc_ch_num_prev : Previous channel num value.
  --                    s_i2c_enable      : Enable signal for I2C master.
  --                    s_i2c_rw          : Read/write for I2C master.
  -- Description      : A process to control the flow of data from and to the
  --                    I2C A/D device.
  ------------------------------------------------------------------------------
  DATA_FLOW_CTRL: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_i2c_busy_prev   <= '1';
      s_adc_ch_num_prev <= "00";
      s_i2c_enable      <= '0';
      s_i2c_rw          <= '1';

    elsif (rising_edge(I_CLK)) then
      -- Latch data inputs for edge detection
      s_i2c_busy_prev   <= s_i2c_busy;
      s_adc_ch_num_prev <= I_ADC_CH_NUM;

      -- Enable signal logic
      if (s_i2c_curr_state /= WAIT_STATE) then
        s_i2c_enable    <= '1';
      else
        s_i2c_enable    <= '0';
      end if;

      -- Read / Write logic
      if (s_i2c_curr_state = WRITE_CONTROL_STATE) then
        s_i2c_rw        <= '0'; -- Writing
      else
        s_i2c_rw        <= '1'; -- Reading
      end if;
    end if;
  end process DATA_FLOW_CTRL;
  ------------------------------------------------------------------------------

  s_wr_data_byte <= "000000" & I_ADC_CH_NUM;  -- Write data to I2C master (always control byte)
  O_ADC_DATA     <= s_rw_data_byte;           -- Read data (always output ADC data)

end architecture behavioral;
