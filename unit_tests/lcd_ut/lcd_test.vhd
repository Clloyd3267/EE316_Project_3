----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/10/2021 04:45:48 PM
-- Design Name: 
-- Module Name: lcd_test - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
  use work.lcd_screen_util.all;

entity lcd_test is
  Port (sys_clk : in std_logic;
        mode_btn : in std_logic;
        clk_gen_btn : in std_logic;
        sda : inout std_logic;
        scl : inout std_logic);
end lcd_test;

architecture Behavioral of lcd_test is
component usr_logic is
port(	clk : 	 in std_logic;
        
        -- Mode of operation
        I_MODE         : in std_logic_vector(1 downto 0) := "00";
  
        -- Clock Generation En
        CLK_GEN_EN	 : in std_logic := '1';
        
		oSDA: 	 inout Std_logic;
		oSCL:	 inout std_logic);
end component usr_logic;

signal clk_gen_en, clk_gen_btn_prev, mode_btn_prev : std_logic := '1';
signal mode : std_logic_vector(1 downto 0) := "00";


begin

LCD : usr_logic port map(clk => sys_clk, I_MODE => mode, CLK_GEN_EN => clk_gen_en, oSDA => sda, oSCL => scl);

BTN_CLK_GEN : process(sys_clk)
begin
    if(rising_edge(sys_clk)) then
        clk_gen_btn_prev <= clk_gen_btn;
        if(clk_gen_btn_prev = '1' and clk_gen_btn = '0') then
            clk_gen_en <= not clk_gen_en;
        end if;
    end if;
end process BTN_CLK_GEN;

BTN_MODE : process(sys_clk)
begin
    if(rising_edge(sys_clk)) then
        mode_btn_prev <= mode_btn;
        if(mode_btn_prev = '1' and mode_btn = '0') then
            mode <= mode + '1';
        end if;
    end if;
end process BTN_MODE;

end Behavioral;
