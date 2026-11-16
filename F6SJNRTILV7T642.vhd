library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ov7670_capture is
    Port (
        pclk  : in   STD_LOGIC;
        vsync : in   STD_LOGIC;
        href  : in   STD_LOGIC;
        d     : in   STD_LOGIC_VECTOR (7 downto 0);
        addr  : out  STD_LOGIC_VECTOR (14 downto 0);
        dout  : out  STD_LOGIC_VECTOR (11 downto 0);
        we    : out  STD_LOGIC;
        col_out : OUT std_logic_vector(7 downto 0); -- ADDED
        row_out : OUT std_logic_vector(6 downto 0)  -- ADDED
    );
end ov7670_capture;

architecture Behavioral of ov7670_capture is
    signal address      : unsigned(14 downto 0) := (others => '0');
    signal row_start    : unsigned(14 downto 0) := (others => '0');
    signal col_count    : unsigned(7 downto 0)  := (others => '0');
    signal row_count    : unsigned(6 downto 0)  := (others => '0');

    signal byte_toggle  : std_logic := '0';
    signal href_prev    : std_logic := '0';
    signal y_byte       : std_logic_vector(7 downto 0) := (others => '0');
    -- Add these signals to the top of your architecture
    signal cam_col : std_logic_vector(7 downto 0);
    signal cam_row : std_logic_vector(6 downto 0);
    
begin

    addr    <= std_logic_vector(address);
    col_out <= std_logic_vector(col_count);
    row_out <= std_logic_vector(row_count);

    process(pclk)
        variable y_nibble : std_logic_vector(3 downto 0);
    begin
        if rising_edge(pclk) then

            we <= '0';
            href_prev <= href;

            if vsync = '1' then
                address     <= (others => '0');
                row_start   <= (others => '0');
                col_count   <= (others => '0');
                row_count   <= (others => '0');
                byte_toggle <= '0';
                y_byte      <= (others => '0');

            elsif href = '1' then

                -- YUV422 byte pair handling:
                -- Store first byte, write it as grayscale on second byte.
                if byte_toggle = '0' then
                    y_byte <= d;
                    byte_toggle <= '1';

                else
                    byte_toggle <= '0';

                    -- Only write first 160 pixels of each row and first 120 rows.
                    if row_count < 120 and col_count < 160 then
                    
                        y_nibble := y_byte(7 downto 4);
                        dout <= y_nibble & y_nibble & y_nibble;
                        --dout <= x"000";
                    
                    we <= '1';
                    address <= address + 1;
                    col_count <= col_count + 1;

                    end if;
                end if;

            else
                byte_toggle <= '0';

                -- Detect falling edge of HREF = end of camera row
                if href_prev = '1' then

                    col_count <= (others => '0');

                    if row_count < 119 then
                        row_count <= row_count + 1;

                        -- Move to next 160-pixel row in BRAM.
                        row_start <= row_start + 160;
                        address   <= row_start + 160;
                    end if;

                end if;
            end if;
        end if;
    end process;

end Behavioral;