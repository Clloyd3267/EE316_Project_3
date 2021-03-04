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

library work;
  use work.lcd_screen_util.all;

--------------
--  Entity  --
--------------
entity lcd_lut is
generic
(
  C_CLK_FREQ_MHZ : integer := 50  -- System clock frequency in MHz
);
port
(
  I_CLK          : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;  -- System reset (active low)

  -- Mode of operation
  I_MODE         : in std_logic_vector(1 downto 0);
  
  -- Clock Generation En
  CLK_GEN_EN	 : in std_logic;

  -- Output Frequency
  I_PWM_FREQ     : in std_logic_vector(1 downto 0);

  -- 16-bit Data (4 hex nibbles)
  I_DATA         : in std_logic_vector(15 downto 0);

  -- 8-bit Address (2 hex nibbles)
  I_ADDRESS      : in std_logic_vector(7 downto 0);

  -- Output LCD "screen" array type (see lcd_display_driver.vhd:19 for type def)
  O_LCD_DATA     : out t_lcd_display_data
);
end entity lcd_lut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of lcd_lut is

  ---------------
  -- Constants --
  ---------------

  -- Mode of Operation
  -- 00: Initialization
  -- 01: Test
  -- 10: Pause
  -- 11: PWM Generation
  constant MODE_LDR : std_logic_vector(1 downto 0) := "00";
  constant MODE_TEMP : std_logic_vector(1 downto 0) := "01";
  constant MODE_ANALOG : std_logic_vector(1 downto 0) := "10";
  constant MODE_POT   : std_logic_vector(1 downto 0) := "11";
  




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
  type t_lcd_addr_ascii is array (1 downto 0) of std_logic_vector(7 downto 0);
  type t_lcd_data_ascii is array (3 downto 0) of std_logic_vector(7 downto 0);
  type t_lcd_freq_ascii is array (6 downto 0) of std_logic_vector(7 downto 0);

  signal s_addr_ascii : t_lcd_addr_ascii := (others=>(others=>('0')));
  signal s_data_ascii : t_lcd_data_ascii := (others=>(others=>('0')));
  signal s_freq_ascii : t_lcd_freq_ascii := (others=>(others=>('0')));

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
    if (I_RESET_N = '0') then
      O_LCD_DATA     <= (others=>(others=>('0')));

    elsif (rising_edge(I_CLK)) then
      
		case(CLK_GEN_EN) is 
			when "0" =>
				case(I_MODE) is -- CDL=> Fix Index/explain
				when MODE_LDR  =>
				  -- [PWM SRC: LDR]
				  -- [  CLK DISABLED  ]
				  O_LCD_DATA <=
				  (
					UP, UW, UM, SP, US, UR, UC, CL, SP, UL, UD, UR, SP, SP, SP, SP,
					SP, SP, UC, UL, UK, SP, UD, UI, US, UA, UB, UL, UE, UD, SP, SP
				  );

				when MODE_TEMP  =>
				  -- [PWM SRC: TEMP]
				  -- [  CLK DISABLED  ]
				  O_LCD_DATA <=
				  (
					UP, UW, UM, SP, US, UR, UC, CL, SP, UT, UE, UM, UP, SP, SP, SP,
					SP, SP, UC, UL, UK, SP, UD, UI, US, UA, UB, UL, UE, UD, SP, SP
				  );

				 when MODE_ANALOG =>
				  -- [PWM SRC: ANALOG]
				  -- [  CLK DISABLED  ]
				  O_LCD_DATA <=
				  (
					UP, UM, UW, SP, US, UR, UC, CL, SP, UA, UN, UA, UL, UO, UG, SP,
					SP, SP, UC, UL, UK, SP, UD, UI, US, UA, UB, UL, UE, UD, SP, SP
				  );

				when MODE_POT   =>
				  -- [PWM SRC: POT]
				  -- [  CLK DISABLED  ]
				  O_LCD_DATA <=
				  (
					UP, UW, UM, SP, US, UR, UC, CL, SP, UP, UO, UT, SP, SP, SP, SP,
					SP, SP, UC, UL, UK, SP, UD, UI, US, UA, UB, UL, UE, UD, SP, SP
				  );

				when others =>
				  O_LCD_DATA <= (others=>(others=>('0')));
				  
				end case;  
			when "1" =>
				case(I_MODE) is -- CDL=> Fix Index/explain
				when MODE_LDR  =>
				  -- [PWM SRC: LDR]
				  -- [CLK FREQ: XXXXHz]
				  O_LCD_DATA <=
				  (
					UP, UW, UM, SP, US, UR, UC, CL, SP, UL, UD, UR, SP, SP, SP, SP,
					UC, UL, UK, SP, UF, UR, UE, UQ, CL, SP, XX, XX, XX, XX, UH, LZ
				  );

				when MODE_TEMP  =>
				  -- [PWM SRC: TEMP]
				  -- [CLK FREQ: XXXXHz]
				  O_LCD_DATA <=
				  (
					UP, UW, UM, SP, US, UR, UC, CL, SP, UT, UE, UM, UP, SP, SP, SP,
					UC, UL, UK, SP, UF, UR, UE, UQ, CL, SP, XX, XX, XX, XX, UH, LZ
				  );

				 when MODE_ANALOG =>
				  -- [PWM SRC: ANALOG]
				  -- [CLK FREQ: XXXXHz]
				  O_LCD_DATA <=
				  (
					UP, UM, UW, SP, US, UR, UC, CL, SP, UA, UN, UA, UL, UO, UG, SP,
					UC, UL, UK, SP, UF, UR, UE, UQ, CL, SP, XX, XX, XX, XX, UH, LZ
				  );

				when MODE_POT   =>
				  -- [PWM SRC: POT]
				  -- [CLK FREQ: XXXXHz]
				  O_LCD_DATA <=
				  (
					UP, UW, UM, SP, US, UR, UC, CL, SP, UP, UO, UT, SP, SP, SP, SP,
					UC, UL, UK, SP, UF, UR, UE, UQ, CL, SP, XX, XX, XX, XX, UH, LZ
				  );

				when others =>
				  O_LCD_DATA <= (others=>(others=>('0')));
				  
				end case;  
      end case;
    end if;
  end process LCD_LUT_DATA_LATCH;
  ------------------------------------------------------------------------------

  -- First bit of address
  s_addr_ascii(0) <= x"3" & I_ADDRESS(3 downto 0) when I_ADDRESS(3 downto 0) < x"A"   -- 0-9
                else x"41"                        when I_ADDRESS(3 downto 0) = x"A"   -- A
                else x"42"                        when I_ADDRESS(3 downto 0) = x"B"   -- B
                else x"43"                        when I_ADDRESS(3 downto 0) = x"C"   -- C
                else x"44"                        when I_ADDRESS(3 downto 0) = x"D"   -- D
                else x"45"                        when I_ADDRESS(3 downto 0) = x"E"   -- E
                else x"46"                        when I_ADDRESS(3 downto 0) = x"F";  -- F


end architecture behavioral;