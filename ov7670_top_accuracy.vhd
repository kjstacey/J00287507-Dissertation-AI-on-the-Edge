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
        vga_vsync     : out   STD_LOGIC
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
    -- Compact EMNIST CNN: triggered once by a completed frozen frame.
    --------------------------------------------------------------------
    signal cnn_done : std_logic;
    signal cnn_class : std_logic_vector(5 downto 0);
    signal cnn_score : std_logic_vector(31 downto 0);
    signal cnn_feature_overflow, cnn_fc_overflow : std_logic;
    signal sw_sync : std_logic_vector(1 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- EMNIST controlled accuracy: 100 images, 784 bytes each.
    -- The test ROM has a synchronous 1-cycle read latency.
    --------------------------------------------------------------------
    type test_state_type is (
        TEST_IDLE, TEST_ADDRESS, TEST_ROM_WAIT, TEST_WRITE,
        TEST_ADVANCE, TEST_RESET_1, TEST_RESET_2,
        TEST_START, TEST_WAIT_DONE, TEST_NEXT, TEST_FINISHED
    );
    signal test_state : test_state_type := TEST_IDLE;
    signal test_index : integer range 0 to EMNIST_TEST_COUNT - 1 := 0;
    signal test_pixel : integer range 0 to EMNIST_PIXELS_PER_IMAGE - 1 := 0;
    signal correct_count : integer range 0 to EMNIST_TEST_COUNT := 0;
    signal processed_count : integer range 0 to EMNIST_TEST_COUNT := 0;
    signal test_complete_flag : std_logic := '0';
    signal test_switch_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal test_rom_addr : std_logic_vector(16 downto 0);
    signal test_rom_data : std_logic_vector(7 downto 0);
    signal test_wr_en : std_logic := '0';
    signal test_wr_addr : std_logic_vector(9 downto 0) := (others => '0');
    signal test_wr_data : std_logic_vector(7 downto 0) := (others => '0');
    signal test_cnn_rst : std_logic := '1';
    signal test_cnn_start : std_logic := '0';

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

    -- Mixed-language Verilog module. Vivado binds this component to the
    -- modified emnist_complete_cnn_bram_top.v added to Design Sources.
    COMPONENT emnist_complete_cnn_bram_top
        PORT (
            clk : IN std_logic; rst : IN std_logic; start : IN std_logic;
            image_wr_clk : IN std_logic; image_wr_en : IN std_logic;
            image_wr_addr : IN std_logic_vector(9 downto 0);
            image_wr_data : IN std_logic_vector(7 downto 0);
            score_read_addr : IN std_logic_vector(5 downto 0);
            score_read_data : OUT std_logic_vector(31 downto 0);
            conv1_finished : OUT std_logic; pool1_finished : OUT std_logic;
            conv2_finished : OUT std_logic; pool2_finished : OUT std_logic;
            conv3_finished : OUT std_logic; gap_finished : OUT std_logic;
            fc_finished : OUT std_logic;
            feature_overflow_seen : OUT std_logic;
            fc_overflow_seen : OUT std_logic;
            predicted_class : OUT std_logic_vector(5 downto 0);
            predicted_score : OUT std_logic_vector(31 downto 0);
            pool1_write_en : OUT std_logic;
            pool1_write_addr : OUT std_logic_vector(11 downto 0);
            pool1_write_data : OUT std_logic_vector(7 downto 0);
            conv2_write_en : OUT std_logic;
            conv2_write_addr : OUT std_logic_vector(12 downto 0);
            conv2_write_data : OUT std_logic_vector(7 downto 0);
            pool2_write_en : OUT std_logic;
            pool2_write_addr : OUT std_logic_vector(10 downto 0);
            pool2_write_data : OUT std_logic_vector(7 downto 0);
            conv3_write_en : OUT std_logic;
            conv3_write_addr : OUT std_logic_vector(11 downto 0);
            conv3_write_data : OUT std_logic_vector(7 downto 0);
            gap_write_en : OUT std_logic;
            gap_write_addr : OUT std_logic_vector(5 downto 0);
            gap_write_data : OUT std_logic_vector(7 downto 0);
            score_write_en : OUT std_logic;
            score_write_addr : OUT std_logic_vector(5 downto 0);
            score_write_data : OUT std_logic_vector(31 downto 0)
        );
    END COMPONENT;
begin
--    ila_nn_valid_vec(0)  <= nn_valid_in;
--ila_scan_done_vec(0) <= nn_scan_done;
--ila_out_valid_vec(0) <= nn_out_valid;
--ila_freeze_vec(0)    <= freeze_stored_clk25;
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
    -- Accuracy begins when sw_view_stored is HIGH, and can be restarted by
    -- returning it LOW and then HIGH after the 100-image test finishes.
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            sw_sync <= sw_sync(0) & sw_view_stored;
            test_switch_sync <= test_switch_sync(0) & sw_view_stored;

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
        test_index * EMNIST_PIXELS_PER_IMAGE + test_pixel, 17));

    test_image_rom : blk_mem_gen_1
        PORT MAP (
            clka => clk25,
            addra => test_rom_addr,
            douta => test_rom_data
        );

    --------------------------------------------------------------------
    -- Load each image into the CNN's *writable* image RAM, reset the CNN
    -- control logic, issue a one-cycle start pulse, and score FC47 output.
    -- One ROM output pipeline stage is assumed (no optional output reg).
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            test_wr_en <= '0';
            test_cnn_start <= '0';

            case test_state is
                when TEST_IDLE =>
                    test_cnn_rst <= '1';
                    if test_switch_sync(1) = '1' then
                        correct_count <= 0;
                        processed_count <= 0;
                        test_index <= 0;
                        test_pixel <= 0;
                        test_complete_flag <= '0';
                        test_state <= TEST_ADDRESS;
                    end if;

                when TEST_ADDRESS =>
                    test_state <= TEST_ROM_WAIT;

                when TEST_ROM_WAIT =>
                    -- ROM data is registered at the clock edge; use it in
                    -- the following state.
                    test_state <= TEST_WRITE;

                when TEST_WRITE =>
                    test_wr_addr <= std_logic_vector(to_unsigned(test_pixel, 10));
                    test_wr_data <= test_rom_data;
                    test_wr_en <= '1';
                    test_state <= TEST_ADVANCE;

                when TEST_ADVANCE =>
                    -- The CNN RAM consumes the prior cycle's write enable.
                    if test_pixel = EMNIST_PIXELS_PER_IMAGE - 1 then
                        test_state <= TEST_RESET_1;
                    else
                        test_pixel <= test_pixel + 1;
                        test_state <= TEST_ADDRESS;
                    end if;

                when TEST_RESET_1 =>
                    test_cnn_rst <= '1';
                    test_state <= TEST_RESET_2;

                when TEST_RESET_2 =>
                    test_cnn_rst <= '1';
                    test_state <= TEST_START;

                when TEST_START =>
                    test_cnn_rst <= '0';
                    test_cnn_start <= '1';
                    test_state <= TEST_WAIT_DONE;

                when TEST_WAIT_DONE =>
                    if cnn_done = '1' then
                        processed_count <= processed_count + 1;
                        if cnn_class = EMNIST_LABEL_ROM(test_index) then
                            correct_count <= correct_count + 1;
                        end if;
                        test_state <= TEST_NEXT;
                    end if;

                when TEST_NEXT =>
                    test_cnn_rst <= '1';
                    if test_index = EMNIST_TEST_COUNT - 1 then
                        test_complete_flag <= '1';
                        test_state <= TEST_FINISHED;
                    else
                        test_index <= test_index + 1;
                        test_pixel <= 0;
                        test_state <= TEST_ADDRESS;
                    end if;

                when TEST_FINISHED =>
                    -- Hold 0..100 correct on LED[6:0], LED7 = completed.
                    if test_switch_sync(1) = '0' then
                        test_complete_flag <= '0';
                        test_state <= TEST_IDLE;
                    end if;
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

    --------------------------------------------------------------------
    -- The existing EMNIST CNN arithmetic and model parameters are unchanged.
    -- For this experiment, the CNN input RAM is loaded from the test ROM.
    --------------------------------------------------------------------
    Inst_emnist_cnn : emnist_complete_cnn_bram_top
        PORT MAP (
            clk => clk25,
            rst => test_cnn_rst,
            start => test_cnn_start,
            image_wr_clk => clk25,
            image_wr_en => test_wr_en,
            image_wr_addr => test_wr_addr,
            image_wr_data => test_wr_data,
            score_read_addr => (others => '0'),
            score_read_data => open,
            conv1_finished => open, pool1_finished => open,
            conv2_finished => open, pool2_finished => open,
            conv3_finished => open, gap_finished => open,
            fc_finished => cnn_done,
            feature_overflow_seen => cnn_feature_overflow,
            fc_overflow_seen => cnn_fc_overflow,
            predicted_class => cnn_class,
            predicted_score => cnn_score,
            pool1_write_en => open, pool1_write_addr => open,
            pool1_write_data => open,
            conv2_write_en => open, conv2_write_addr => open,
            conv2_write_data => open,
            pool2_write_en => open, pool2_write_addr => open,
            pool2_write_data => open,
            conv3_write_en => open, conv3_write_addr => open,
            conv3_write_data => open,
            gap_write_en => open, gap_write_addr => open,
            gap_write_data => open,
            score_write_en => open, score_write_addr => open,
            score_write_data => open
        );

    -- Accuracy output: LED[6:0] is the 0..100 correct count.
    -- LED[7] turns on when all 100 images have been processed.
    LED(6 downto 0) <= std_logic_vector(to_unsigned(correct_count, 7));
    LED(7) <= test_complete_flag;

end Behavioral;
