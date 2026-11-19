library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.emnist_test_rom_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity ov7670_top is
    Port ( 
        clk100         : in    STD_LOGIC;

        OV7670_SIOC   : out   STD_LOGIC;
        OV7670_SIOD   : inout STD_LOGIC;
        OV7670_RESET  : out   STD_LOGIC;
        OV7670_PWDN   : out   STD_LOGIC;
        OV7670_VSYNC  : in    STD_LOGIC;
        OV7670_HREF   : in    STD_LOGIC;
        OV7670_PCLK   : in    STD_LOGIC;
        OV7670_XCLK   : out   STD_LOGIC;
        OV7670_D      : in    STD_LOGIC_VECTOR(7 downto 0);

        LED           : out   STD_LOGIC_VECTOR(7 downto 0);

        btn           : in    STD_LOGIC;
        btn_capture   : in    STD_LOGIC;
        sw_view_stored: in    STD_LOGIC;

        vga_red       : out   STD_LOGIC_VECTOR(3 downto 0);
        vga_green     : out   STD_LOGIC_VECTOR(3 downto 0);
        vga_blue      : out   STD_LOGIC_VECTOR(3 downto 0);
        vga_hsync     : out   STD_LOGIC;
        vga_vsync     : out   STD_LOGIC;

        -- Port B of the AXI-accessible, true dual-port BRAM mailbox.
        -- Addresses are BYTE offsets into the shared BRAM.
        mailbox_clkb  : out std_logic;
        mailbox_web   : out std_logic_vector(3 downto 0);
        mailbox_addrb : out std_logic_vector(31 downto 0);
        mailbox_dinb  : out std_logic_vector(31 downto 0);
        mailbox_doutb : in  std_logic_vector(31 downto 0)
    );
end ov7670_top;

architecture Behavioral of ov7670_top is

    --------------------------------------------------------------------
    -- Clocks
    --------------------------------------------------------------------
    signal clk50, clk25, buffered_pclk : std_logic;

    --------------------------------------------------------------------
    -- Camera / live frame buffer
    --------------------------------------------------------------------
    signal resend, config_finished : std_logic;

    signal capture_addr : std_logic_vector(14 downto 0);
    signal frame_addr   : std_logic_vector(14 downto 0);
    signal capture_data : std_logic_vector(11 downto 0);
    signal capture_we   : std_logic;
    signal live_doutb   : std_logic_vector(11 downto 0);

    signal capture_col  : std_logic_vector(7 downto 0);
    signal capture_row  : std_logic_vector(6 downto 0);

    --------------------------------------------------------------------
    -- VGA
    --------------------------------------------------------------------
    signal vga_h_count    : std_logic_vector(9 downto 0);
    signal vga_v_count    : std_logic_vector(9 downto 0);
    signal selected_pixel : std_logic_vector(11 downto 0);
    signal in_stored_box  : std_logic;

    --------------------------------------------------------------------
    -- Stored 28x28 BRAM
    --------------------------------------------------------------------
    signal stored_doutb        : std_logic_vector(7 downto 0);
    signal stored_addr_read    : unsigned(9 downto 0) := (others => '0');
    signal addr_to_stored_bram : std_logic_vector(9 downto 0);
    signal wea_stored_vec      : std_logic_vector(0 downto 0) := "0";

    --------------------------------------------------------------------
    -- Button / freeze control
    --------------------------------------------------------------------
    signal btn_cap_debounced : std_logic;
    signal btn_cap_sync      : std_logic_vector(2 downto 0) := (others => '0');
    signal btn_armed         : std_logic := '1';

    signal freeze_request_toggle : std_logic := '0';
    signal freeze_req_sync_pclk  : std_logic_vector(2 downto 0) := (others => '0');
    signal freeze_pending_pclk   : std_logic := '0';
    signal freeze_stored_pclk    : std_logic := '0';

    signal freeze_sync_clk25     : std_logic_vector(2 downto 0) := (others => '0');
    signal freeze_stored_clk25   : std_logic := '0';
    signal freeze_prev           : std_logic := '0';

    --------------------------------------------------------------------
    -- Direct ROI address/data for stable 28x28 capture
    --------------------------------------------------------------------
    signal roi_write_pending : std_logic := '0';
    signal roi_addr_reg      : unsigned(9 downto 0) := (others => '0');
    signal roi_data_reg      : std_logic_vector(7 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Controlled cloud test: 100 EMNIST images from the existing ROM.
    -- The ARM SDK application performs accuracy and timing recording.
    --------------------------------------------------------------------
    signal sw_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal test_rom_addr : std_logic_vector(16 downto 0) := (others => '0');
    signal test_rom_data : std_logic_vector(7 downto 0);

    type mailbox_state_type is (
        MB_IDLE, MB_SET_ADDR, MB_WAIT_ROM, MB_CAPTURE,
        MB_WRITE_WORD, MB_WRITE_IMAGE_INDEX, MB_WRITE_EXPECTED,
        MB_WRITE_STATUS, MB_STATUS_HOLD,
        MB_STATUS_ADDR, MB_STATUS_WAIT, MB_STATUS_CHECK,
        MB_RESULT_ADDR, MB_RESULT_WAIT, MB_RESULT_CAPTURE,
        MB_CLEAR_STATUS, MB_NEXT_IMAGE, MB_TEST_DONE
    );
    signal mailbox_state : mailbox_state_type := MB_IDLE;
    signal image_index : integer range 0 to EMNIST_TEST_COUNT - 1 := 0;
    signal pixel_index : integer range 0 to EMNIST_PIXELS_PER_IMAGE - 1 := 0;
    signal word_index  : integer range 0 to 195 := 0;
    signal byte_index  : integer range 0 to 3 := 0;
    signal word_buffer : std_logic_vector(31 downto 0) := (others => '0');

    signal mailbox_we_reg   : std_logic_vector(3 downto 0) := (others => '0');
    signal mailbox_addr_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal mailbox_din_reg  : std_logic_vector(31 downto 0) := (others => '0');

    signal predicted_class  : std_logic_vector(5 downto 0) := (others => '0');
    signal correct_count    : integer range 0 to EMNIST_TEST_COUNT := 0;
    signal test_done_flag   : std_logic := '0';

    --------------------------------------------------------------------
    -- Components
    --------------------------------------------------------------------
    COMPONENT clocking
        PORT (
            CLK_100 : IN  std_logic;
            CLK_50  : OUT std_logic;
            CLK_25  : OUT std_logic
        );
    END COMPONENT;

    COMPONENT debounce
        PORT (
            clk : IN  std_logic;
            i   : IN  std_logic;
            o   : OUT std_logic
        );
    END COMPONENT;

    COMPONENT ov7670_controller
        PORT (
            clk             : IN    std_logic;
            resend          : IN    std_logic;
            config_finished : OUT   std_logic;
            sioc            : OUT   std_logic;
            siod            : INOUT std_logic;
            reset           : OUT   std_logic;
            pwdn            : OUT   std_logic;
            xclk            : OUT   std_logic
        );
    END COMPONENT;

    COMPONENT ov7670_capture
        PORT (
            pclk    : IN  std_logic;
            vsync   : IN  std_logic;
            href    : IN  std_logic;
            d       : IN  std_logic_vector(7 downto 0);
            addr    : OUT std_logic_vector(14 downto 0);
            dout    : OUT std_logic_vector(11 downto 0);
            we      : OUT std_logic;
            col_out : OUT std_logic_vector(7 downto 0);
            row_out : OUT std_logic_vector(6 downto 0)
        );
    END COMPONENT;

    COMPONENT vga
        PORT (
            clk25       : IN  std_logic;
            vga_red     : OUT std_logic_vector(3 downto 0);
            vga_green   : OUT std_logic_vector(3 downto 0);
            vga_blue    : OUT std_logic_vector(3 downto 0);
            vga_hsync   : OUT std_logic;
            vga_vsync   : OUT std_logic;
            frame_addr  : OUT std_logic_vector(14 downto 0);
            frame_pixel : IN  std_logic_vector(11 downto 0);
            h_count_out : OUT std_logic_vector(9 downto 0);
            v_count_out : OUT std_logic_vector(9 downto 0)
        );
    END COMPONENT;

    COMPONENT blk_mem_gen_0
        PORT (
            clka  : IN  std_logic;
            clkb  : IN  std_logic;
            wea   : IN  std_logic_vector(0 downto 0);
            addra : IN  std_logic_vector(14 downto 0);
            addrb : IN  std_logic_vector(14 downto 0);
            dina  : IN  std_logic_vector(11 downto 0);
            doutb : OUT std_logic_vector(11 downto 0)
        );
    END COMPONENT;

    COMPONENT blk_mem_gen_stored
        PORT (
            clka  : IN  std_logic;
            clkb  : IN  std_logic;
            wea   : IN  std_logic_vector(0 downto 0);
            addra : IN  std_logic_vector(9 downto 0);
            addrb : IN  std_logic_vector(9 downto 0);
            dina  : IN  std_logic_vector(7 downto 0);
            doutb : OUT std_logic_vector(7 downto 0)
        );
    END COMPONENT;

    -- Rename this component if your Block Memory Generator IP has a
    -- different module name. Port A is 8 bits x 78,400 words, 17-bit address.
    COMPONENT blk_mem_gen_1
        PORT (
            clka : IN std_logic;
            addra : IN std_logic_vector(16 downto 0);
            douta : OUT std_logic_vector(7 downto 0)
        );
    END COMPONENT;

begin
    mailbox_clkb  <= clk25;
    mailbox_web   <= mailbox_we_reg;
    mailbox_addrb <= mailbox_addr_reg;
    mailbox_dinb  <= mailbox_din_reg;

    --------------------------------------------------------------------
    -- Clocking
    --------------------------------------------------------------------
    Inst_clocking : clocking
        PORT MAP (
            CLK_100 => clk100,
            CLK_50  => clk50,
            CLK_25  => clk25
        );

    IBUFG_inst : IBUFG
        PORT MAP (
            I => OV7670_PCLK,
            O => buffered_pclk
        );

    --------------------------------------------------------------------
    -- Debounce
    --------------------------------------------------------------------
    res_deb : debounce
        PORT MAP (
            clk => clk50,
            i   => btn,
            o   => resend
        );

    cap_deb : debounce
        PORT MAP (
            clk => clk50,
            i   => btn_capture,
            o   => btn_cap_debounced
        );

    --------------------------------------------------------------------
    -- clk50 domain: button toggles freeze request
    --------------------------------------------------------------------
    process(clk50)
    begin
        if rising_edge(clk50) then

            btn_cap_sync <= btn_cap_sync(1 downto 0) & btn_cap_debounced;

            if btn_cap_sync(2) = '0' then
                btn_armed <= '1';
            end if;

            if btn_cap_sync(2) = '1' and btn_armed = '1' then
                freeze_request_toggle <= not freeze_request_toggle;
                btn_armed <= '0';
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- buffered_pclk domain: stable 28x28 write + freeze at end of frame
    --------------------------------------------------------------------
    process(buffered_pclk)
        variable c_int        : integer;
        variable r_int        : integer;
        variable roi_addr_int : integer;
    begin
        if rising_edge(buffered_pclk) then

            c_int := to_integer(unsigned(capture_col));
            r_int := to_integer(unsigned(capture_row));

            wea_stored_vec <= "0";

            -- Complete delayed BRAM write from previous valid ROI sample.
            if roi_write_pending = '1' then
                wea_stored_vec <= "1";
                roi_write_pending <= '0';
            end if;

            -- Synchronize freeze request into PCLK domain.
            freeze_req_sync_pclk <= freeze_req_sync_pclk(1 downto 0) & freeze_request_toggle;

            if freeze_req_sync_pclk(2) /= freeze_req_sync_pclk(1) then
                if freeze_stored_pclk = '1' then
                    -- unfreeze immediately
                    freeze_stored_pclk <= '0';
                    freeze_pending_pclk <= '0';
                else
                    -- request freeze after current complete 28x28 capture
                    freeze_pending_pclk <= '1';
                end if;
            end if;

            -- Only update stored image while not frozen.
            if freeze_stored_pclk = '0' then

                if (capture_we = '1') and
                   (c_int >= 24 and c_int < 136) and
                   (r_int >= 4  and r_int < 116) and
                   ((c_int - 24) mod 4 = 0) and
                   ((r_int - 4) mod 4 = 0) then

                    roi_addr_int := ((r_int - 4) / 4) * 28 + ((c_int - 24) / 4);

                    roi_addr_reg <= to_unsigned(roi_addr_int, 10);

                    -- Restore the verified MNIST camera preprocessing while
                    -- validating camera-to-CNN data flow.  The selected camera
                    -- sample is either 0x7F or 0x00 (not grayscale).
                    if capture_data(11 downto 8) > x"7" then
                        roi_data_reg <= x"7F";
                    else
                        roi_data_reg <= x"00";
                    end if;

                    roi_write_pending <= '1';

                    -- Freeze only after bottom-right ROI sample has been queued.
                    if freeze_pending_pclk = '1' and
                       c_int = 132 and
                       r_int = 112 then

                        freeze_stored_pclk <= '1';
                        freeze_pending_pclk <= '0';
                    end if;

                end if;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Stored thumbnail box area
    --------------------------------------------------------------------
    in_stored_box <= '1' when
        (unsigned(vga_h_count) >= 300 and unsigned(vga_h_count) < 328) and
        (unsigned(vga_v_count) >= 200 and unsigned(vga_v_count) < 228)
    else '0';

    --------------------------------------------------------------------
    -- clk25 domain: VGA remains available; CNN uses test-image ROM only.
    -- Continuous ROM workload starts when sw_view_stored is HIGH.
    -- After each 100-image pass, the state machine restarts at image 0.
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            sw_sync <= sw_sync(0) & sw_view_stored;
            --test_switch_sync <= test_switch_sync(0) & sw_view_stored;

            if sw_sync(1) = '0' then
                stored_addr_read <= (others => '0');
            elsif unsigned(vga_h_count) = 300 and
                  unsigned(vga_v_count) = 200 then
                stored_addr_read <= (others => '0');
            elsif in_stored_box = '1' then
                if stored_addr_read < 783 then
                    stored_addr_read <= stored_addr_read + 1;
                end if;
            end if;
        end if;
    end process;

    addr_to_stored_bram <= std_logic_vector(stored_addr_read);

    test_rom_addr <= std_logic_vector(to_unsigned(
        image_index * EMNIST_PIXELS_PER_IMAGE + pixel_index, 17));

    test_image_rom : blk_mem_gen_1
        PORT MAP (
            clka => clk25,
            addra => test_rom_addr,
            douta => test_rom_data
        );

    --------------------------------------------------------------------
    -- EMNIST ROM -> shared mailbox -> ARM/Cloud Run -> mailbox result.
    -- Matches the SDK offsets from the MNIST 100-image experiment.
    -- One synchronous ROM read and synchronous BRAM read are assumed.
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            mailbox_we_reg <= "0000";

            case mailbox_state is
                when MB_IDLE =>
                    if sw_sync(1) = '1' then
                        image_index <= 0;
                        pixel_index <= 0;
                        word_index <= 0;
                        byte_index <= 0;
                        correct_count <= 0;
                        test_done_flag <= '0';
                        word_buffer <= (others => '0');
                        mailbox_state <= MB_SET_ADDR;
                    end if;

                when MB_SET_ADDR =>
                    mailbox_state <= MB_WAIT_ROM;

                when MB_WAIT_ROM =>
                    mailbox_state <= MB_CAPTURE;

                when MB_CAPTURE =>
                    case byte_index is
                        when 0 => word_buffer(7 downto 0) <= test_rom_data;
                        when 1 => word_buffer(15 downto 8) <= test_rom_data;
                        when 2 => word_buffer(23 downto 16) <= test_rom_data;
                        when 3 => word_buffer(31 downto 24) <= test_rom_data;
                        when others => null;
                    end case;
                    if byte_index = 3 then
                        mailbox_state <= MB_WRITE_WORD;
                    else
                        pixel_index <= pixel_index + 1;
                        byte_index <= byte_index + 1;
                        mailbox_state <= MB_SET_ADDR;
                    end if;

                when MB_WRITE_WORD =>
                    mailbox_we_reg <= "1111";
                    mailbox_addr_reg <= std_logic_vector(to_unsigned(word_index * 4, 32));
                    mailbox_din_reg <= word_buffer;
                    if pixel_index = EMNIST_PIXELS_PER_IMAGE - 1 then
                        mailbox_state <= MB_WRITE_IMAGE_INDEX;
                    else
                        pixel_index <= pixel_index + 1;
                        word_index <= word_index + 1;
                        byte_index <= 0;
                        word_buffer <= (others => '0');
                        mailbox_state <= MB_SET_ADDR;
                    end if;

                when MB_WRITE_IMAGE_INDEX =>
                  
                    mailbox_we_reg <= "1111";
                    mailbox_addr_reg <= x"00000314";
                    -- Index 0..99 per batch, as expected by SDK recorder.
                    mailbox_din_reg <= std_logic_vector(to_unsigned(image_index, 32));
                    mailbox_state <= MB_WRITE_EXPECTED;

                when MB_WRITE_EXPECTED =>
                    
                    mailbox_we_reg <= "1111";
                    mailbox_addr_reg <= x"0000031C";
                    mailbox_din_reg <= std_logic_vector(resize(
                        unsigned(EMNIST_LABEL_ROM(image_index)), 32));
                    mailbox_state <= MB_WRITE_STATUS;

                when MB_WRITE_STATUS =>
                   
                    mailbox_we_reg <= "1111";
                    mailbox_addr_reg <= x"00000310";
                    mailbox_din_reg <= x"00000001";
                    mailbox_state <= MB_STATUS_HOLD;

                when MB_STATUS_HOLD =>
                    
                    mailbox_we_reg <= "1111";
                    mailbox_addr_reg <= x"00000310";
                    mailbox_din_reg <= x"00000001";
                    mailbox_state <= MB_STATUS_ADDR;

                when MB_STATUS_ADDR =>
                   
                    mailbox_we_reg <= "0000";
                    mailbox_addr_reg <= x"00000310";
                    mailbox_state <= MB_STATUS_WAIT;

                when MB_STATUS_WAIT =>
                  
                    mailbox_we_reg <= "0000";
                    mailbox_addr_reg <= x"00000310";
                    mailbox_state <= MB_STATUS_CHECK;

                when MB_STATUS_CHECK =>
                    if mailbox_doutb = x"00000002" then
                        mailbox_state <= MB_RESULT_ADDR;
                    else
                        mailbox_state <= MB_STATUS_ADDR;
                    end if;

                when MB_RESULT_ADDR =>
                    
                    mailbox_we_reg <= "0000";
                    mailbox_addr_reg <= x"00000318";
                    mailbox_state <= MB_RESULT_WAIT;

                when MB_RESULT_WAIT =>
                    
                    mailbox_we_reg <= "0000";
                    mailbox_addr_reg <= x"00000318";
                    mailbox_state <= MB_RESULT_CAPTURE;

                when MB_RESULT_CAPTURE =>
                    predicted_class <= mailbox_doutb(5 downto 0);
                    if mailbox_doutb(5 downto 0) = EMNIST_LABEL_ROM(image_index) then
                        correct_count <= correct_count + 1;
                    end if;
                    mailbox_state <= MB_CLEAR_STATUS;

                when MB_CLEAR_STATUS =>
                 
                    mailbox_we_reg <= "1111";
                    mailbox_addr_reg <= x"00000310";
                    mailbox_din_reg <= x"00000000";
                    mailbox_state <= MB_NEXT_IMAGE;

                when MB_NEXT_IMAGE =>
                    if image_index = EMNIST_TEST_COUNT - 1 then
                        -- A full 100-image pass has completed. Toggle LED7
                        -- so repeated passes remain observable without USB.
                        test_done_flag <= not test_done_flag;

                        -- Restart the ROM at image zero and clear the per-pass
                        -- correct counter to avoid overflow on later passes.
                        image_index <= 0;
                        correct_count <= 0;
                        pixel_index <= 0;
                        word_index <= 0;
                        byte_index <= 0;
                        word_buffer <= (others => '0');
                        mailbox_state <= MB_SET_ADDR;
                    else
                        image_index <= image_index + 1;
                        pixel_index <= 0;
                        word_index <= 0;
                        byte_index <= 0;
                        word_buffer <= (others => '0');
                        mailbox_state <= MB_SET_ADDR;
                    end if;

                when MB_TEST_DONE =>
                    -- Not entered during continuous power testing.
                    mailbox_state <= MB_IDLE;
            end case;
        end if;
    end process;

    --------------------------------------------------------------------
    -- VGA pixel mux
    --------------------------------------------------------------------
    -- Restore MNIST-style binary thumbnail display. Any nonzero
    -- stored pixel appears white; zero appears black.
    selected_pixel <= x"FFF"
                      when (sw_sync(1) = '1' and in_stored_box = '1'
                            and stored_doutb /= x"00") else
                      x"000"
                      when (sw_sync(1) = '1' and in_stored_box = '1') else
                      x"222" when sw_sync(1) = '1' else live_doutb;

    --------------------------------------------------------------------
    -- Live frame buffer
    --------------------------------------------------------------------
    fb_live : blk_mem_gen_0
        PORT MAP (
            clka  => buffered_pclk,
            wea(0)=> capture_we,
            addra => capture_addr,
            dina  => capture_data,

            clkb  => clk25,
            addrb => frame_addr,
            doutb => live_doutb
        );

    --------------------------------------------------------------------
    -- Stored 28x28 BRAM
    --------------------------------------------------------------------
    fb_stored : blk_mem_gen_stored
        PORT MAP (
            clka  => buffered_pclk,
            wea   => wea_stored_vec,
            addra => std_logic_vector(roi_addr_reg),
            dina  => roi_data_reg,

            clkb  => clk25,
            addrb => addr_to_stored_bram,
            doutb => stored_doutb
        );

    --------------------------------------------------------------------
    -- Camera controller
    --------------------------------------------------------------------
    Inst_ov7670_controller : ov7670_controller
        PORT MAP (
            clk             => clk50,
            resend          => resend,
            config_finished => config_finished,
            sioc            => OV7670_SIOC,
            siod            => OV7670_SIOD,
            reset           => OV7670_RESET,
            pwdn            => OV7670_PWDN,
            xclk            => OV7670_XCLK
        );

    --------------------------------------------------------------------
    -- Camera capture
    --------------------------------------------------------------------
    Inst_ov7670_capture : ov7670_capture
        PORT MAP (
            pclk    => buffered_pclk,
            vsync   => OV7670_VSYNC,
            href    => OV7670_HREF,
            d       => OV7670_D,
            addr    => capture_addr,
            dout    => capture_data,
            we      => capture_we,
            col_out => capture_col,
            row_out => capture_row
        );

    --------------------------------------------------------------------
    -- VGA
    --------------------------------------------------------------------
    Inst_vga : vga
        PORT MAP (
            clk25       => clk25,
            vga_red     => vga_red,
            vga_green   => vga_green,
            vga_blue    => vga_blue,
            vga_hsync   => vga_hsync,
            vga_vsync   => vga_vsync,
            frame_addr  => frame_addr,
            frame_pixel => selected_pixel,
            h_count_out => vga_h_count,
            v_count_out => vga_v_count
        );

    -- LED[6:0] displays the correct count within the current 100-image pass.
    -- LED7 toggles on each completed pass (visible heartbeat without USB).
    LED(6 downto 0) <= std_logic_vector(to_unsigned(correct_count, 7));
    LED(7) <= test_done_flag;

end Behavioral;
