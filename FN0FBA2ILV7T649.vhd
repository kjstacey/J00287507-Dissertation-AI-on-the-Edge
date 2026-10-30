library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga is
    Port ( clk25       : in  STD_LOGIC;
           vga_red     : out STD_LOGIC_VECTOR (3 downto 0);
           vga_green   : out STD_LOGIC_VECTOR (3 downto 0);
           vga_blue    : out STD_LOGIC_VECTOR (3 downto 0);
           vga_hsync   : out STD_LOGIC;
           vga_vsync   : out STD_LOGIC;
           frame_addr  : out STD_LOGIC_VECTOR (14 downto 0); -- UPDATED TO 15-BIT
           frame_pixel : in  STD_LOGIC_VECTOR (11 downto 0);
           h_count_out : out STD_LOGIC_VECTOR (9 downto 0);
           v_count_out : out STD_LOGIC_VECTOR (9 downto 0));
end vga;

architecture Behavioral of vga is
   signal h_cnt : unsigned(9 downto 0) := (others => '0');
   signal v_cnt : unsigned(9 downto 0) := (others => '0');
   signal addr  : unsigned(14 downto 0) := (others => '0');

begin
   h_count_out <= std_logic_vector(h_cnt);
   v_count_out <= std_logic_vector(v_cnt);
   frame_addr  <= std_logic_vector(addr);

  process(clk25)
   begin
      if rising_edge(clk25) then
   
         -- Sync / counter logic
         if h_cnt = 799 then
            h_cnt <= (others => '0');
   
            if v_cnt = 524 then
               v_cnt <= (others => '0');
               addr  <= (others => '0');
            else
               v_cnt <= v_cnt + 1;
            end if;
         else
            h_cnt <= h_cnt + 1;
         end if;
   
         -- Standard VGA timing
         if h_cnt >= 656 and h_cnt < 752 then
            vga_hsync <= '0';
         else
            vga_hsync <= '1';
         end if;
   
         if v_cnt >= 490 and v_cnt < 492 then
            vga_vsync <= '0';
         else
            vga_vsync <= '1';
         end if;
   
         -- BRAM read address:
         -- only advance while drawing the 160x120 camera window
         if (h_cnt >= 240 and h_cnt < 400) and
            (v_cnt >= 180 and v_cnt < 300) then
   
            if addr < 19199 then
               addr <= addr + 1;
            end if;
         end if;
   
         -- RGB output:
         -- show camera only inside the same 160x120 window
         if (h_cnt >= 240 and h_cnt < 400) and
            (v_cnt >= 180 and v_cnt < 300) then
   
            vga_red   <= frame_pixel(11 downto 8);
            vga_green <= frame_pixel(7 downto 4);
            vga_blue  <= frame_pixel(3 downto 0);
   
         else
            vga_red   <= (others => '0');
            vga_green <= (others => '0');
            vga_blue  <= (others => '0');
         end if;
   
      end if;
   end process;
end Behavioral;