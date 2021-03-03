--------------------------------------------------------------------------------
-- Filename     : dac_i2c_driver.vhd
-- Author(s)    : Chris Lloyd, Thomas Griebel, Anthony Seybolt
-- Class        : EE316 (Project 3)
-- Due Date     : 2021-02-23
-- Target Board : Cora 7Z010
-- Entity       : dac_i2c_driver
-- Description  : CDL=> Uses:
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
entity dac_i2c_driver is
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
end entity dac_i2c_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of dac_i2c_driver is
  ----------------
  -- Components --
  ----------------
  component i2c_master is
  generic
  (
    input_clk : integer := 125_000_000;               -- Input clock speed from user logic in Hz
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

  constant C_I2C_DAC_ADDR        : std_logic_vector(7 downto 0) := x"48";  -- Default address is 0x48
  constant C_WR_BYTE_INDEX_MAX   : integer := 1; -- CDL=> Here

  constant C_I2C_DAC_CTRL_BYTE   : std_logic_vector(7 downto 0) := x"40";

  -------------
  -- SIGNALS --
  -------------

  -- State machine related signals
  type T_DAC_STATE is (READY_STATE, WRITE_STATE, WAIT_STATE, NEXT_STATE);
  signal s_i2c_curr_state       : T_DAC_STATE := READY_STATE;

  signal s_i2c_enable           : std_logic;
  signal s_wr_data_byte         : std_logic_vector(7 downto 0);
  signal s_wr_data_byte_index   : integer;

  signal s_i2c_wr               : std_logic;  --'0' is write, '1' is read
  signal s_i2c_address          : std_logic_vector(6 downto 0) := C_I2C_DAC_ADDR(6 downto 0);
  signal s_i2c_busy             : std_logic;
  signal s_data_latched         : std_logic_vector(7 downto 0);

begin

  -- I2C controller for 4 digit Seven Segment Display
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
    rw        => s_i2c_wr,
    data_wr   => s_wr_data_byte,
    busy      => s_i2c_busy,
    data_rd   => open,
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
  -- Useful Outputs   : s_i2c_curr_state : Current state of S7D write process.
  -- Description      : State machine to control different states for I2C
  --                    Seven Segment Display (7SD) module.
  ------------------------------------------------------------------------------
  I2C_STATE_MACHINE: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_i2c_curr_state             <= READY_STATE;

    elsif (rising_edge(I_CLK)) then
        -- I2C state machine logic
        case s_i2c_curr_state is
          when READY_STATE =>
            if (s_data_latched /= I_DAC_DATA) then
              s_i2c_curr_state     <= WRITE_STATE;
            else
              s_i2c_curr_state     <= s_i2c_curr_state;
            end if;

          when WRITE_STATE =>
            s_i2c_curr_state       <= WAIT_STATE;

          when WAIT_STATE =>
            if (s_i2c_busy = '1') then
              s_i2c_curr_state     <= NEXT_STATE;
            else
              s_i2c_curr_state     <= s_i2c_curr_state;
            end if;

            when NEXT_STATE =>
              if (s_i2c_busy = '0') then
                if (s_wr_data_byte_index /= C_WR_BYTE_INDEX_MAX) then
                  s_i2c_curr_state <= WRITE_STATE;
                else
                  s_i2c_curr_state <= READY_STATE;
                end if;
              else
                s_i2c_curr_state   <= s_i2c_curr_state;
              end if;

          -- Error condition, should never occur
          when others =>
            s_i2c_curr_state       <= READY_STATE;
        end case;
    end if;
  end process I2C_STATE_MACHINE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : DATA_FLOW_CTRL
  -- Sensitivity List : I_CLK                  : System clock
  --                    I_RESET_N              : System reset (active low logic)
  -- Useful Outputs   : s_display_data_latched : Latched data to remain stable.
  --                    s_7sd_enable           : Enable signal for I2C master.
  --                    s_wr_data_byte_index   : Current data byte index.
  --                    O_BUSY                 : Output busy signal.
  -- Description      : Process to increment index counter representing current
  --                    data byte to send. LUT table in (WRITE_DATA_LUT). Also
  --                    controls enable signal for I2C master, and output busy
  --                    signal.
  ------------------------------------------------------------------------------
  DATA_FLOW_CTRL: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_data_latched     <= (others=>'0');
      s_i2c_enable               <= '0';
      s_wr_data_byte_index       <=  0;
      O_BUSY                     <= '1';

    elsif (rising_edge(I_CLK)) then
      if (I_DAC_ENABLE = '1') then
      
      if ()
      
        -- Latch data so it does not change during write
        if (s_i2c_curr_state = READY_STATE) then
          s_data_latched  <= I_DAC_DATA;
        else
          s_data_latched  <= s_data_latched;
        end if;

        -- Enable signal logic
--        if (s_i2c_curr_state = WRITE_STATE) then
--          s_i2c_enable             <= '1';
--        elsif (s_i2c_curr_state = WAIT_STATE) and
--              (s_i2c_busy = '1') then
--          s_i2c_enable             <= '0';
--        else
--          s_i2c_enable             <= s_i2c_enable;
--        end if;
        if (s_i2c_curr_state /= READY_STATE) then
          s_i2c_enable             <= '1';
        else
          s_i2c_enable             <= '0';
        end if;

        -- Data Byte Index logic
        if (s_i2c_curr_state = NEXT_STATE) and (s_i2c_busy = '0') then
          if (s_wr_data_byte_index /= C_WR_BYTE_INDEX_MAX) then
            s_wr_data_byte_index <= s_wr_data_byte_index + 1;
          else
            s_wr_data_byte_index <= 0;
          end if;
        else
          s_wr_data_byte_index     <= s_wr_data_byte_index;
        end if;

        -- Output Busy logic
        if (s_i2c_curr_state = READY_STATE) then
          O_BUSY                   <= '0';
        else
          O_BUSY                   <= '1';
        end if;
      else
        s_data_latched     <= (others=>'1');
        s_i2c_enable               <= '0';
        s_wr_data_byte_index       <=  0;
        O_BUSY                     <= '1';      
      end if;
    end if;
  end process DATA_FLOW_CTRL;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : WRITE_DATA_LUT
  -- Sensitivity List : I_CLK          : System clock
  --                    I_RESET_N      : System reset (active low logic)
  -- Useful Outputs   : s_wr_data_byte : Data byte to send to Display
  -- Description      : Process to act as Look Up Table (LUT) to decide what
  --                    byte to send to display based on (s_wr_data_byte_index).
  ------------------------------------------------------------------------------
  WRITE_DATA_LUT: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_wr_data_byte                  <= C_I2C_DAC_CTRL_BYTE;
    elsif (rising_edge(I_CLK)) then
      case s_wr_data_byte_index is
--        when 0      => s_wr_data_byte <= C_I2C_DAC_ADDR;
        when 0      => s_wr_data_byte <= C_I2C_DAC_CTRL_BYTE;
        when 1      => s_wr_data_byte <= s_data_latched;
        when others => s_wr_data_byte <= s_data_latched;
      end case;
    end if;
  end process WRITE_DATA_LUT;
  ------------------------------------------------------------------------------

  s_i2c_wr <= '0'; -- Always writing

end architecture behavioral;
