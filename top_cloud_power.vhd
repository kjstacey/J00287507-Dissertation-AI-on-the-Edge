library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.vcomponents.all;
use work.mnist_test_rom_pkg.all;

entity ov7670_top is
    Port (
        clk100         : in    STD_LOGIC;

        OV7670_SIOC    : out   STD_LOGIC;
        OV7670_SIOD    : inout STD_LOGIC;
        OV7670_RESET   : out   STD_LOGIC;
        OV7670_PWDN    : out   STD_LOGIC;
        OV7670_VSYNC   : in    STD_LOGIC;
        OV7670_HREF    : in    STD_LOGIC;
        OV7670_PCLK    : in    STD_LOGIC;
        OV7670_XCLK    : out   STD_LOGIC;
        OV7670_D       : in    STD_LOGIC_VECTOR(7 downto 0);

        LED            : out   STD_LOGIC_VECTOR(7 downto 0);

        btn            : in    STD_LOGIC;
        btn_capture    : in    STD_LOGIC;
        sw_view_stored : in    STD_LOGIC;

        vga_red        : out   STD_LOGIC_VECTOR(3 downto 0);
        vga_green      : out   STD_LOGIC_VECTOR(3 downto 0);
        vga_blue       : out   STD_LOGIC_VECTOR(3 downto 0);
        vga_hsync      : out   STD_LOGIC;
        vga_vsync      : out   STD_LOGIC;

        ----------------------------------------------------------------
        -- Cloud mailbox BRAM Port B
        ----------------------------------------------------------------
        mailbox_clkb   : out std_logic;
        mailbox_enb    : out std_logic;
        mailbox_web    : out std_logic_vector(3 downto 0);
        mailbox_addrb  : out std_logic_vector(31 downto 0);
        mailbox_dinb   : out std_logic_vector(31 downto 0);
        mailbox_doutb  : in  std_logic_vector(31 downto 0);
        mailbox_rstb   : out std_logic
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

    --------------------------------------------------------------------
    -- Direct ROI address/data for stable 28x28 capture
    --------------------------------------------------------------------
    signal roi_write_pending : std_logic := '0';
    signal roi_addr_reg      : unsigned(9 downto 0) := (others => '0');
    signal roi_data_reg      : std_logic_vector(7 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Cloud mailbox interface
    --------------------------------------------------------------------
    signal mailbox_en_reg   : std_logic := '0';
    signal mailbox_we_reg   : std_logic_vector(3 downto 0) := (others => '0');
    signal mailbox_addr_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal mailbox_din_reg  : std_logic_vector(31 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Controlled MNIST power-test ROM
    --------------------------------------------------------------------
    signal mnist_rom_addr : std_logic_vector(16 downto 0) := (others => '0');
    signal mnist_rom_dout : std_logic_vector(7 downto 0);

    --------------------------------------------------------------------
    -- Cloud mailbox state machine
    --------------------------------------------------------------------
    type mailbox_state_type is (
        MB_IDLE,

        MB_SET_ADDR,
        MB_WAIT_ROM,
        MB_CAPTURE,
        MB_WRITE_WORD,

        MB_WRITE_IMAGE_INDEX,
        MB_WRITE_EXPECTED_LABEL,
        MB_WRITE_STATUS,
        MB_WRITE_STATUS_HOLD,

        MB_STATUS_ADDR,
        MB_STATUS_WAIT,
        MB_STATUS_CHECK,

        MB_RESULT_ADDR,
        MB_RESULT_WAIT,
        MB_RESULT_CAPTURE,

        MB_CLEAR_STATUS,
        MB_NEXT_IMAGE,
        MB_TEST_DONE
    );

    signal mailbox_state : mailbox_state_type := MB_IDLE;

    signal mailbox_pixel_index : integer range 0 to 783 := 0;
    signal mailbox_word_index  : integer range 0 to 195 := 0;
    signal mailbox_byte_index  : integer range 0 to 3 := 0;

    signal mailbox_word_buffer : std_logic_vector(31 downto 0)
        := (others => '0');

    signal cloud_result_latch : std_logic_vector(3 downto 0)
        := (others => '0');

    signal cloud_result_valid : std_logic := '0';

    signal mailbox_image_index :
        integer range 0 to MNIST_TEST_COUNT - 1 := 0;

    signal mailbox_test_done : std_logic := '0';

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

    COMPONENT blk_mem_gen_mnist_test
        PORT (
            clka  : IN  std_logic;
            addra : IN  std_logic_vector(16 downto 0);
            douta : OUT std_logic_vector(7 downto 0)
        );
    END COMPONENT;

begin

    --------------------------------------------------------------------
    -- Cloud mailbox BRAM interface
    --------------------------------------------------------------------
    mailbox_clkb <= clk25;
    mailbox_rstb <= '0';

    mailbox_enb   <= mailbox_en_reg;
    mailbox_web   <= mailbox_we_reg;
    mailbox_addrb <= mailbox_addr_reg;
    mailbox_dinb  <= mailbox_din_reg;

    --------------------------------------------------------------------
    -- MNIST controlled test-data ROM
    --
    -- This ROM remains in the cloud power-test build only so that a
    -- repeatable 100-image workload can be supplied to the PS/cloud path.
    --------------------------------------------------------------------
    mnist_test_rom : blk_mem_gen_mnist_test
        PORT MAP (
            clka  => clk25,
            addra => mnist_rom_addr,
            douta => mnist_rom_dout
        );

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

            btn_cap_sync <=
                btn_cap_sync(1 downto 0) & btn_cap_debounced;

            if btn_cap_sync(2) = '0' then
                btn_armed <= '1';
            end if;

            if btn_cap_sync(2) = '1' and
               btn_armed = '1' then

                freeze_request_toggle <=
                    not freeze_request_toggle;

                btn_armed <= '0';

            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- buffered_pclk domain:
    -- stable 28x28 camera write + freeze at completed ROI
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

            --------------------------------------------------------------
            -- Complete delayed BRAM write
            --------------------------------------------------------------
            if roi_write_pending = '1' then
                wea_stored_vec   <= "1";
                roi_write_pending <= '0';
            end if;

            --------------------------------------------------------------
            -- Synchronize freeze request into camera clock domain
            --------------------------------------------------------------
            freeze_req_sync_pclk <=
                freeze_req_sync_pclk(1 downto 0) &
                freeze_request_toggle;

            if freeze_req_sync_pclk(2) /=
               freeze_req_sync_pclk(1) then

                if freeze_stored_pclk = '1' then

                    freeze_stored_pclk  <= '0';
                    freeze_pending_pclk <= '0';

                else

                    freeze_pending_pclk <= '1';

                end if;

            end if;

            --------------------------------------------------------------
            -- Update stored 28x28 image only while not frozen
            --------------------------------------------------------------
            if freeze_stored_pclk = '0' then

                if (capture_we = '1') and
                   (c_int >= 24 and c_int < 136) and
                   (r_int >= 4  and r_int < 116) and
                   ((c_int - 24) mod 4 = 0) and
                   ((r_int - 4) mod 4 = 0) then

                    roi_addr_int :=
                        ((r_int - 4) / 4) * 28 +
                        ((c_int - 24) / 4);

                    roi_addr_reg <=
                        to_unsigned(roi_addr_int, 10);

                    ------------------------------------------------------
                    -- Binary threshold, MNIST-style
                    ------------------------------------------------------
                    if capture_data(11 downto 8) > x"7" then
                        roi_data_reg <= x"7F";
                    else
                        roi_data_reg <= x"00";
                    end if;

                    roi_write_pending <= '1';

                    ------------------------------------------------------
                    -- Freeze only after final ROI sample is queued
                    ------------------------------------------------------
                    if freeze_pending_pclk = '1' and
                       c_int = 132 and
                       r_int = 112 then

                        freeze_stored_pclk  <= '1';
                        freeze_pending_pclk <= '0';

                    end if;

                end if;

            end if;

        end if;

    end process;

    --------------------------------------------------------------------
    -- Stored thumbnail box area
    --------------------------------------------------------------------
    in_stored_box <= '1'
        when
            (unsigned(vga_h_count) >= 300 and
             unsigned(vga_h_count) < 328) and
            (unsigned(vga_v_count) >= 200 and
             unsigned(vga_v_count) < 228)
        else '0';

    --------------------------------------------------------------------
    -- Controlled multi-image CLOUD power-test workload
    --
    -- Local zyNet has been completely removed from this build.
    --
    -- sw_view_stored = 1 begins the 100-image cloud workload.
    --------------------------------------------------------------------
    process(clk25)
    begin

        if rising_edge(clk25) then

            --------------------------------------------------------------
            -- Default BRAM controls
            --------------------------------------------------------------
            mailbox_en_reg <= '0';
            mailbox_we_reg <= "0000";

            case mailbox_state is

                ----------------------------------------------------------
                -- Wait for experiment trigger
                ----------------------------------------------------------
                when MB_IDLE =>

                    cloud_result_valid <= '0';
                    mailbox_test_done  <= '0';

                    if sw_view_stored = '1' then

                        mailbox_image_index <= 0;

                        mailbox_pixel_index <= 0;
                        mailbox_word_index  <= 0;
                        mailbox_byte_index  <= 0;

                        mailbox_word_buffer <=
                            (others => '0');

                        mailbox_state <= MB_SET_ADDR;

                    end if;

                ----------------------------------------------------------
                -- Present MNIST ROM address
                ----------------------------------------------------------
                when MB_SET_ADDR =>

                    mailbox_state <= MB_WAIT_ROM;

                ----------------------------------------------------------
                -- Allow synchronous ROM output to update
                ----------------------------------------------------------
                when MB_WAIT_ROM =>

                    mailbox_state <= MB_CAPTURE;

                ----------------------------------------------------------
                -- Capture one byte from test ROM
                ----------------------------------------------------------
                when MB_CAPTURE =>

                    case mailbox_byte_index is

                        when 0 =>
                            mailbox_word_buffer(7 downto 0)
                                <= mnist_rom_dout;

                        when 1 =>
                            mailbox_word_buffer(15 downto 8)
                                <= mnist_rom_dout;

                        when 2 =>
                            mailbox_word_buffer(23 downto 16)
                                <= mnist_rom_dout;

                        when 3 =>
                            mailbox_word_buffer(31 downto 24)
                                <= mnist_rom_dout;

                        when others =>
                            null;

                    end case;

                    if mailbox_byte_index = 3 then

                        mailbox_state <= MB_WRITE_WORD;

                    else

                        mailbox_pixel_index <=
                            mailbox_pixel_index + 1;

                        mailbox_byte_index <=
                            mailbox_byte_index + 1;

                        mailbox_state <= MB_SET_ADDR;

                    end if;

                ----------------------------------------------------------
                -- Write four packed pixels into shared mailbox BRAM
                ----------------------------------------------------------
                when MB_WRITE_WORD =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        std_logic_vector(
                            to_unsigned(
                                mailbox_word_index * 4,
                                32
                            )
                        );

                    mailbox_din_reg <=
                        mailbox_word_buffer;

                    if mailbox_pixel_index = 783 then

                        mailbox_state <=
                            MB_WRITE_IMAGE_INDEX;

                    else

                        mailbox_pixel_index <=
                            mailbox_pixel_index + 1;

                        mailbox_word_index <=
                            mailbox_word_index + 1;

                        mailbox_byte_index <= 0;

                        mailbox_word_buffer <=
                            (others => '0');

                        mailbox_state <=
                            MB_SET_ADDR;

                    end if;

                ----------------------------------------------------------
                -- Write image number to 0x314
                ----------------------------------------------------------
                when MB_WRITE_IMAGE_INDEX =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"00000314";

                    mailbox_din_reg <=
                        std_logic_vector(
                            to_unsigned(
                                mailbox_image_index,
                                32
                            )
                        );

                    mailbox_state <=
                        MB_WRITE_EXPECTED_LABEL;

                ----------------------------------------------------------
                -- Write expected MNIST label to 0x31C
                ----------------------------------------------------------
                when MB_WRITE_EXPECTED_LABEL =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"0000031C";

                    mailbox_din_reg <=
                        std_logic_vector(
                            resize(
                                unsigned(
                                    MNIST_LABEL_ROM(
                                        mailbox_image_index
                                    )
                                ),
                                32
                            )
                        );

                    mailbox_state <=
                        MB_WRITE_STATUS;

                ----------------------------------------------------------
                -- Tell ARM that image is ready
                -- STATUS = 1
                ----------------------------------------------------------
                when MB_WRITE_STATUS =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_din_reg <=
                        x"00000001";

                    mailbox_state <=
                        MB_WRITE_STATUS_HOLD;

                ----------------------------------------------------------
                -- Hold STATUS write for full BRAM clock
                ----------------------------------------------------------
                when MB_WRITE_STATUS_HOLD =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_din_reg <=
                        x"00000001";

                    mailbox_state <=
                        MB_STATUS_ADDR;

                ----------------------------------------------------------
                -- Request STATUS read
                ----------------------------------------------------------
                when MB_STATUS_ADDR =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "0000";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_state <=
                        MB_STATUS_WAIT;

                ----------------------------------------------------------
                -- Wait for synchronous BRAM read
                ----------------------------------------------------------
                when MB_STATUS_WAIT =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "0000";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_state <=
                        MB_STATUS_CHECK;

                ----------------------------------------------------------
                -- Wait for ARM to set STATUS = 2
                ----------------------------------------------------------
                when MB_STATUS_CHECK =>

                    if mailbox_doutb =
                       x"00000002" then

                        mailbox_state <=
                            MB_RESULT_ADDR;

                    else

                        mailbox_state <=
                            MB_STATUS_ADDR;

                    end if;

                ----------------------------------------------------------
                -- Request RESULT @ 0x318
                ----------------------------------------------------------
                when MB_RESULT_ADDR =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "0000";

                    mailbox_addr_reg <=
                        x"00000318";

                    mailbox_state <=
                        MB_RESULT_WAIT;

                ----------------------------------------------------------
                -- Wait for synchronous RESULT read
                ----------------------------------------------------------
                when MB_RESULT_WAIT =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "0000";

                    mailbox_addr_reg <=
                        x"00000318";

                    mailbox_state <=
                        MB_RESULT_CAPTURE;

                ----------------------------------------------------------
                -- Capture returned cloud prediction
                ----------------------------------------------------------
                when MB_RESULT_CAPTURE =>

                    cloud_result_latch <=
                        mailbox_doutb(3 downto 0);

                    cloud_result_valid <= '1';

                    mailbox_state <=
                        MB_CLEAR_STATUS;

                ----------------------------------------------------------
                -- Clear handshake before next image
                -- STATUS = 0
                ----------------------------------------------------------
                when MB_CLEAR_STATUS =>

                    mailbox_en_reg <= '1';
                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_din_reg <=
                        x"00000000";

                    mailbox_state <=
                        MB_NEXT_IMAGE;

                ----------------------------------------------------------
                -- Advance to next image or finish workload
                ----------------------------------------------------------
                when MB_NEXT_IMAGE =>

                    if mailbox_image_index <
                       MNIST_TEST_COUNT - 1 then

                        mailbox_image_index <=
                            mailbox_image_index + 1;

                        mailbox_pixel_index <= 0;
                        mailbox_word_index  <= 0;
                        mailbox_byte_index  <= 0;

                        mailbox_word_buffer <=
                            (others => '0');

                        mailbox_state <=
                            MB_SET_ADDR;

                    else

    ----------------------------------------------------------
    -- Continuous cloud power-test workload
    --
    -- Toggle LED7 after each completed 100-image pass so
    -- activity can be observed after USB/JTAG/UART cables
    -- are disconnected.
    ----------------------------------------------------------
    mailbox_test_done <= not mailbox_test_done;

    ----------------------------------------------------------
    -- Restart from image 0 without resetting the FPGA or
    -- closing the persistent TLS connection.
    ----------------------------------------------------------
    mailbox_image_index <= 0;

    mailbox_pixel_index <= 0;
    mailbox_word_index  <= 0;
    mailbox_byte_index  <= 0;

    mailbox_word_buffer <=
        (others => '0');

    mailbox_state <=
        MB_SET_ADDR;

end if;

                ----------------------------------------------------------
                -- 100-image workload complete
                ----------------------------------------------------------
                when MB_TEST_DONE =>

                    mailbox_test_done  <= '1';
                    cloud_result_valid <= '1';

                    ------------------------------------------------------
                    -- Preserve current one-shot behavior.
                    -- Remain here until FPGA reset/reprogramming.
                    ------------------------------------------------------
                    mailbox_state <= MB_TEST_DONE;

            end case;

        end if;

    end process;

    --------------------------------------------------------------------
    -- clk25 domain: stored-thumbnail VGA read address
    --------------------------------------------------------------------
    process(clk25)
    begin

        if rising_edge(clk25) then

            if sw_view_stored = '0' then

                stored_addr_read <=
                    (others => '0');

            elsif unsigned(vga_h_count) = 300 and
                  unsigned(vga_v_count) = 200 then

                stored_addr_read <=
                    (others => '0');

            elsif in_stored_box = '1' then

                if stored_addr_read < 783 then

                    stored_addr_read <=
                        stored_addr_read + 1;

                end if;

            end if;

        end if;

    end process;

    --------------------------------------------------------------------
    -- MNIST power-test ROM address
    --
    -- Local NN addressing has been removed.  The ROM is now owned only
    -- by the cloud mailbox workload.
    --------------------------------------------------------------------
    mnist_rom_addr <=
        std_logic_vector(
            to_unsigned(
                (mailbox_image_index *
                 MNIST_PIXELS_PER_IMAGE)
                +
                mailbox_pixel_index,
                17
            )
        );

    --------------------------------------------------------------------
    -- Stored BRAM read address
    --
    -- With local zyNet removed, VGA exclusively owns this read port.
    --------------------------------------------------------------------
    addr_to_stored_bram <=
        std_logic_vector(stored_addr_read);

    --------------------------------------------------------------------
    -- VGA pixel mux
    --------------------------------------------------------------------
    selected_pixel <=
        x"FFF"
        when
            (sw_view_stored = '1' and
             in_stored_box = '1' and
             stored_doutb /= x"00")
        else

        x"000"
        when
            (sw_view_stored = '1' and
             in_stored_box = '1')
        else

        x"222"
        when
            (sw_view_stored = '1')
        else

        live_doutb;

    --------------------------------------------------------------------
    -- Live frame buffer
    --------------------------------------------------------------------
    fb_live : blk_mem_gen_0
        PORT MAP (
            clka   => buffered_pclk,
            wea(0) => capture_we,
            addra  => capture_addr,
            dina   => capture_data,

            clkb   => clk25,
            addrb  => frame_addr,
            doutb  => live_doutb
        );

    --------------------------------------------------------------------
    -- Stored 28x28 BRAM
    --------------------------------------------------------------------
    fb_stored : blk_mem_gen_stored
        PORT MAP (
            clka  => buffered_pclk,
            wea   => wea_stored_vec,
            addra => std_logic_vector(
                         roi_addr_reg
                     ),
            dina  => roi_data_reg,

            clkb  => clk25,
            addrb => addr_to_stored_bram,
            doutb => stored_doutb
        );

    --------------------------------------------------------------------
    -- Camera controller
    --------------------------------------------------------------------
    Inst_ov7670_controller :
        ov7670_controller

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
    Inst_ov7670_capture :
        ov7670_capture

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
    Inst_vga :
        vga

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
    -- LEDs
    --
    -- LED7 = completed 100-image cloud workload
    -- LED3..0 = most recent returned cloud prediction
    --------------------------------------------------------------------
    LED <=
        mailbox_test_done &
        "000" &
        cloud_result_latch;

end Behavioral;