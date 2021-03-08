-- Testbench for LCD 
library IEEE;
use IEEE.std_logic_1164.all;
 
entity lcd_tb is
port(
    clk :in std_logic
);
end lcd_tb; 

architecture tb of lcd_tb is


component lut is
port
(
  I_CLK          : in std_logic;
  I_RESET_N      : in std_logic;
  I_MODE         : in std_logic_vector(1 downto 0);
  CLK_GEN_EN	 : in std_logic);
end component;
component usr_logic is
port 
(
    oSDA : inout std_logic;
    oSCL : inout std_logic
);
end component;
--signal  clk:  std_logic;
signal  mode:  std_logic_vector(1 downto 0) := '0';
signal  clk_gen_en:  std_logic := '1';
signal sda : std_logic;
signal scl : std_logic;
signal reset: std_logic; 

begin

  -- Connect DUT
 -- DUT: fulladder2bit port map(a=>a, b=>b, cin=>cin, sum=>sum, carry=>carry);
	DUT: lut port map(I_CLK => clk, I_RESET_N => reset, I_MODE => mode, CLK_GEN_EN => clk_gen_en);
	DUT2: usr_logic port map(oSDA => sda, oSCL => scl);
  process
  begin
    I_RESET_N = '1';
    mode <= "00";
	clk_gen_en <= '1';
	wait for 10ns;
    wait;
  end process;
end tb;
