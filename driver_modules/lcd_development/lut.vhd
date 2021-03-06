--------------------------------------------------------------------------------
-- Filename     : lcd_lut.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 2)
-- Due Date     : 2021-02-23
-- Target Board : Altera DE2 Devkit
-- Entity       : lcd_lut
-- Description  : A lookup table (lut) to decide what data (O_LCD_DATA) gets
--                displayed to the LCD module depending on the current mode
--                (I_MODE).
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package lcd_screen_util is
type t_lcd_display_data is array (31 downto 0) of std_logic_vector(7 downto 0);
end package lcd_screen_util;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
  use work.lcd_screen_util.all;
--------------
--  Entity  --
--------------
entity lut is
generic
(
  C_CLK_FREQ_MHZ : integer := 125  -- System clock frequency in MHz
);
port
(
  I_CLK          : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic := '1';  -- System reset (active low)

  I_IN_MODE     : in std_logic_vector(1 downto 0) := "00";
  I_OUT_MODE    : in std_logic_vector(1 downto 0) := "00";

  -- Output LCD "screen" array type (see lcd_display_driver.vhd:19 for type def)
  O_LCD_DATA     : out t_lcd_display_data
);
end entity lut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of lut is

  ---------------
  -- Constants --
  ---------------

  -- ADC channel number / Data inputs
  constant C_ADC_LDR       : std_logic_vector(1 downto 0) := "00";  -- LDR
  constant C_ADC_TMP       : std_logic_vector(1 downto 0) := "01";  -- TEMP
  constant C_ADC_POT       : std_logic_vector(1 downto 0) := "11";  -- POT
  constant C_ADC_ANA       : std_logic_vector(1 downto 0) := "10";  -- ANALOG IN

  -- Data outputs
  constant C_OUT_PWM       : std_logic_vector(1 downto 0) := "00";
  constant C_OUT_CLK       : std_logic_vector(1 downto 0) := "01";
  constant C_OUT_DAC       : std_logic_vector(1 downto 0) := "10";
  constant C_OUT_DISABLED  : std_logic_vector(1 downto 0) := "11";

  -- Ascii constants for writing "Strings"
  -- Upper case alphabet
  constant UA  : std_logic_vector(7 downto 0) := x"41";  -- A
  constant UB  : std_logic_vector(7 downto 0) := x"42";  -- B
  constant UC  : std_logic_vector(7 downto 0) := x"43";  -- C
  constant UD  : std_logic_vector(7 downto 0) := x"44";  -- D
  constant UE  : std_logic_vector(7 downto 0) := x"45";  -- E
  constant UF  : std_logic_vector(7 downto 0) := x"46";  -- F
  constant UG  : std_logic_vector(7 downto 0) := x"47";  -- G
  constant UH  : std_logic_vector(7 downto 0) := x"48";  -- H
  constant UI  : std_logic_vector(7 downto 0) := x"49";  -- I
  constant UJ  : std_logic_vector(7 downto 0) := x"4A";  -- J
  constant UK  : std_logic_vector(7 downto 0) := x"4B";  -- K
  constant UL  : std_logic_vector(7 downto 0) := x"4C";  -- L
  constant UM  : std_logic_vector(7 downto 0) := x"4D";  -- M
  constant UN  : std_logic_vector(7 downto 0) := x"4E";  -- N
  constant UO  : std_logic_vector(7 downto 0) := x"4F";  -- O
  constant UP  : std_logic_vector(7 downto 0) := x"50";  -- P
  constant UQ  : std_logic_vector(7 downto 0) := x"51";  -- Q
  constant UR  : std_logic_vector(7 downto 0) := x"52";  -- R
  constant US  : std_logic_vector(7 downto 0) := x"53";  -- S
  constant UT  : std_logic_vector(7 downto 0) := x"54";  -- T
  constant UU  : std_logic_vector(7 downto 0) := x"55";  -- U
  constant UV  : std_logic_vector(7 downto 0) := x"56";  -- V
  constant UW  : std_logic_vector(7 downto 0) := x"57";  -- W
  constant UX  : std_logic_vector(7 downto 0) := x"58";  -- X
  constant UY  : std_logic_vector(7 downto 0) := x"59";  -- Y
  constant UZ  : std_logic_vector(7 downto 0) := x"5A";  -- Z

  -- Lower case alphabet
  constant LA  : std_logic_vector(7 downto 0) := x"61";  -- a
  constant LB  : std_logic_vector(7 downto 0) := x"62";  -- b
  constant LC  : std_logic_vector(7 downto 0) := x"63";  -- c
  constant LD  : std_logic_vector(7 downto 0) := x"64";  -- d
  constant LE  : std_logic_vector(7 downto 0) := x"65";  -- e
  constant LF  : std_logic_vector(7 downto 0) := x"66";  -- f
  constant LG  : std_logic_vector(7 downto 0) := x"67";  -- g
  constant LH  : std_logic_vector(7 downto 0) := x"68";  -- h
  constant LI  : std_logic_vector(7 downto 0) := x"69";  -- i
  constant LJ  : std_logic_vector(7 downto 0) := x"6A";  -- j
  constant LK  : std_logic_vector(7 downto 0) := x"6B";  -- k
  constant LL  : std_logic_vector(7 downto 0) := x"6C";  -- l
  constant LM  : std_logic_vector(7 downto 0) := x"6D";  -- m
  constant LN  : std_logic_vector(7 downto 0) := x"6E";  -- n
  constant LO  : std_logic_vector(7 downto 0) := x"6F";  -- o
  constant LP  : std_logic_vector(7 downto 0) := x"70";  -- p
  constant LQ  : std_logic_vector(7 downto 0) := x"71";  -- q
  constant LR  : std_logic_vector(7 downto 0) := x"72";  -- r
  constant LS  : std_logic_vector(7 downto 0) := x"73";  -- s
  constant LT  : std_logic_vector(7 downto 0) := x"74";  -- t
  constant LU  : std_logic_vector(7 downto 0) := x"75";  -- u
  constant LV  : std_logic_vector(7 downto 0) := x"76";  -- v
  constant LW  : std_logic_vector(7 downto 0) := x"77";  -- w
  constant LX  : std_logic_vector(7 downto 0) := x"78";  -- x
  constant LY  : std_logic_vector(7 downto 0) := x"79";  -- y
  constant LZ  : std_logic_vector(7 downto 0) := x"7A";  -- z

  -- Numeric 0-9
  constant N0    : std_logic_vector(7 downto 0) := x"30";  -- 0
  constant N1    : std_logic_vector(7 downto 0) := x"31";  -- 1
  constant N2    : std_logic_vector(7 downto 0) := x"32";  -- 2
  constant N3    : std_logic_vector(7 downto 0) := x"33";  -- 3
  constant N4    : std_logic_vector(7 downto 0) := x"34";  -- 4
  constant N5    : std_logic_vector(7 downto 0) := x"35";  -- 5
  constant N6    : std_logic_vector(7 downto 0) := x"36";  -- 6
  constant N7    : std_logic_vector(7 downto 0) := x"37";  -- 7
  constant N8    : std_logic_vector(7 downto 0) := x"38";  -- 8
  constant N9    : std_logic_vector(7 downto 0) := x"39";  -- 9

  -- Other useful constants
  constant SP : std_logic_vector(7 downto 0) := x"20";  -- Space
  constant EX : std_logic_vector(7 downto 0) := x"21";  -- !
  constant CL : std_logic_vector(7 downto 0) := x"3A";  -- :

  -------------
  -- SIGNALS --
  -------------
  type t_lcd_inout_ascii is array (2 downto 0) of std_logic_vector(7 downto 0);
  signal s_input_mode : t_lcd_inout_ascii := (others=>(others=>('0')));
  signal s_output_mode : t_lcd_inout_ascii := (others=>(others=>('0')));

begin

  ------------------------------------------------------------------------------
  -- Process Name     : LCD_LUT_DATA_LATCH
  -- Sensitivity List : I_CLK               : System clock
  --                    I_RESET_N           : System reset (active low logic)
  -- Useful Outputs   :
  -- Description      :
  ------------------------------------------------------------------------------
  LCD_LUT_DATA_LATCH: process (I_CLK, I_RESET_N)
  begin
    -- if (I_RESET_N = '0') then
    --   O_LCD_DATA     <= (others=>(others=>('0')));

    if (rising_edge(I_CLK)) then
      -- [  INPUT : ___   ]
      -- [ OUTPUT : ___   ]
      -- O_LCD_DATA <=
      -- (
      --   SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, s_input_mode(2),  s_input_mode(1),  s_input_mode(0), SP, SP, SP,
      --   SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, s_output_mode(2), s_output_mode(1), s_output_mode(0), SP, SP, SP
      -- );

      -- O_LCD_DATA <=
      -- (
      --   SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UL, UD, UR, SP, SP, SP,
      --   SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP
      -- );

      -- if (I_IN_MODE = C_ADC_LDR) then
      --   O_LCD_DATA <=
      --   (
      --     SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP,
      --     SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UL, UD, UR, SP, SP, SP
      --   );
      -- else
      --   O_LCD_DATA <=
      --   (
      --     SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP,
      --     SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UP, UO, UT, SP, SP, SP
      --   );
      -- end if;
      if    (I_IN_MODE = C_ADC_LDR) then
        if    (I_OUT_MODE = C_OUT_PWM) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UP, UW, UM, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UL, UD, UR, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_CLK) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UC, UL, UK, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UL, UD, UR, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_DAC) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UL, UD, UR, SP, SP, SP
          );
        else -- C_OUT_DISABLED
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UO, UF, UF, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UL, UD, UR, SP, SP, SP
          );
        end if;
      elsif (I_IN_MODE = C_ADC_TMP) then
        if    (I_OUT_MODE = C_OUT_PWM) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UP, UW, UM, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UT, UM, UP, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_CLK) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UC, UL, UK, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UT, UM, UP, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_DAC) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UT, UM, UP, SP, SP, SP
          );
        else -- C_OUT_DISABLED
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UO, UF, UF, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UT, UM, UP, SP, SP, SP
          );
        end if;

      elsif (I_IN_MODE = C_ADC_ANA) then
        if    (I_OUT_MODE = C_OUT_PWM) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UP, UW, UM, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UA, UN, UA, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_CLK) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UC, UL, UK, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UA, UN, UA, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_DAC) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UA, UN, UA, SP, SP, SP
          );
        else -- C_OUT_DISABLED
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UO, UF, UF, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UA, UN, UA, SP, SP, SP
          );
        end if;

      else -- C_ADC_POT
        if    (I_OUT_MODE = C_OUT_PWM) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UP, UW, UM, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UP, UO, UT, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_CLK) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UC, UL, UK, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UP, UO, UT, SP, SP, SP
          );
        elsif (I_OUT_MODE = C_OUT_DAC) then
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UD, UA, UC, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UP, UO, UT, SP, SP, SP
          );
        else -- C_OUT_DISABLED
          O_LCD_DATA <=
          (
            SP, UO, UU, UT, UP, UU, UT, SP, CL, SP, UO, UF, UF, SP, SP, SP,
            SP, SP, UI, UN, UP, UU, UT, SP, CL, SP, UP, UO, UT, SP, SP, SP
          );
        end if;
      end if;
    end if;
  end process LCD_LUT_DATA_LATCH;
  ------------------------------------------------------------------------------

  -- s_input_mode <= (UL, UD, UR) when I_IN_MODE = C_ADC_LDR
  --            else (UT, UM, UP) when I_IN_MODE = C_ADC_TMP
  --            else (UP, UO, UT) when I_IN_MODE = C_ADC_POT
  --            else (UA, UN, UA) when I_IN_MODE = C_ADC_ANA;

  -- s_output_mode <= (UP, UW, UM) when I_OUT_MODE = C_OUT_PWM
  --             else (UC, UL, UK) when I_OUT_MODE = C_OUT_CLK
  --             else (UD, UA, UC) when I_OUT_MODE = C_OUT_DAC
  --             else (UO, UF, UF) when I_OUT_MODE = C_OUT_DISABLED;

end architecture behavioral;