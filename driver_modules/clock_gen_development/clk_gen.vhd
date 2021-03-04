--Similar to Version 1.1, But With the Test Processes and Hardcoded desired_clk Removed to Prepare for ADC Implementation

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

entity clk_gen is
    port(sys_clk : in std_logic;
         enable_btn : in std_logic;
         desired_clk : in std_logic_vector(7 downto 0);
         output_clk : out std_logic;
         led_0 : out std_logic);
end clk_gen;

architecture Behavioral of clk_gen is
signal counter : std_logic_vector(16 downto 0) := '0'&X"0000";
signal variable_counter : std_logic_vector(16 downto 0) := '0'&X"0000";
signal temp_output_clk : std_logic := '1';
signal enable_btn_prev: std_logic;
signal enable : std_logic := '1';

signal converted_desired_clk : std_logic_vector(16 downto 0) := '0'&X"0000";
constant desired_clk_min: natural := 0;
constant desired_clk_max: natural := 16#FF#;
constant converted_desired_clk_min: natural := 16#0A2C3#;
constant converted_desired_clk_max: natural := 16#1E848#;
signal x, y: natural;
signal m : natural := (converted_desired_clk_max - converted_desired_clk_min) / (desired_clk_max - desired_clk_min);
signal b : natural := converted_desired_clk_max - m * desired_clk_max;

begin

CLKGEN : process(sys_clk, enable)
begin
    if(enable = '0') then
        led_0 <= '0';
        output_clk <= '0';
    elsif(rising_edge(sys_clk)) then
        led_0 <= '1';
        counter <= counter + '1';
        if(counter = variable_counter) then
            variable_counter <= variable_counter + converted_desired_clk;
            temp_output_clk <= not temp_output_clk;
        end if;
        output_clk <= temp_output_clk;
    end if;
end process CLKGEN;

CONVERSION : process(sys_clk, desired_clk)
begin
    if(rising_edge(sys_clk) and enable ='1') then
        x <= to_integer(unsigned(desired_clk));
        y <= m * x + b;
        converted_desired_clk <= std_logic_vector(to_unsigned(y, converted_desired_clk'length));
    end if;
end process CONVERSION;

BTN_EN: process(sys_clk)
begin
    if(rising_edge(sys_clk)) then
        enable_btn_prev <= enable_btn;
        if(enable_btn_prev = '1' and enable_btn = '0') then
            enable <= not enable;
        end if;
    end if;
end process BTN_EN;
    
end Behavioral;
