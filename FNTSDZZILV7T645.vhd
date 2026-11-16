----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Mike Field <hamster@sanp.net.nz> 
-- 
-- Description: Register settings for the OV7670 Caamera (partially from OV7670.c
--              in the Linux Kernel
------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ov7670_registers is
    Port ( clk      : in  STD_LOGIC; 
           resend   : in  STD_LOGIC;
           advance  : in  STD_LOGIC;
           command  : out  std_logic_vector(15 downto 0);
           finished : out  STD_LOGIC);
end ov7670_registers;

architecture Behavioral of ov7670_registers is
	signal sreg   : std_logic_vector(15 downto 0);
	signal address : std_logic_vector(7 downto 0) := (others => '0');
begin
	command <= sreg;
	with sreg select finished  <= '1' when x"FFFF", '0' when others;
	
	process(clk)
	begin
		if rising_edge(clk) then
			if resend = '1' then 
				address <= (others => '0');
			elsif advance = '1' then
				address <= std_logic_vector(unsigned(address)+1);
			end if;

			case address is
				-- OV7670 clean init (QQVGA, YUV, stable)
            
                when x"00" => sreg <= x"1280"; -- COM7 reset
                when x"01" => sreg <= x"1280"; -- COM7 reset
                when x"02" => sreg <= x"1200"; -- COM7 YUV
                when x"03" => sreg <= x"1101"; -- CLKRC
                when x"04" => sreg <= x"0400"; -- COM1 no CCIR656
                when x"05" => sreg <= x"1510"; -- COM10 rising-edge PCLK capture
                when x"06" => sreg <= x"8C00"; -- RGB444 off
                when x"07" => sreg <= x"40C0"; -- COM15 full range
                when x"08" => sreg <= x"3A04"; -- TSLB
                
                when x"09" => sreg <= x"1428"; -- COM9 lower gain ceiling
                when x"0A" => sreg <= x"138D"; -- COM8 AGC/AEC on, AWB off
                when x"0B" => sreg <= x"B104"; -- ABLC on
                when x"0C" => sreg <= x"4100"; -- COM16
                when x"0D" => sreg <= x"3F00"; -- EDGE off
                when x"0E" => sreg <= x"3D80"; -- COM13
                
                when x"0F" => sreg <= x"0C04"; -- COM3 scaling
                when x"10" => sreg <= x"3E1A"; -- COM14 QQVGA
                when x"11" => sreg <= x"703A"; -- SCALING_XSC
                when x"12" => sreg <= x"7135"; -- SCALING_YSC
                when x"13" => sreg <= x"7222"; -- SCALING_DCWCTR
                when x"14" => sreg <= x"73F2"; -- SCALING_PCLK_DIV
                when x"15" => sreg <= x"A202"; -- SCALING_PCLK_DELAY
                
                when others => sreg <= x"FFFF";
			end case;
		end if;
	end process;
end Behavioral;

