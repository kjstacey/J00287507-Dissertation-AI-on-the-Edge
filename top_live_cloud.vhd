library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.vcomponents.all;


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
    signal clk50         : std_logic;
    signal clk25         : std_logic;
    signal buffered_pclk : std_logic;


    --------------------------------------------------------------------
    -- Camera / live frame buffer
    --------------------------------------------------------------------
    signal resend          : std_logic;
    signal config_finished : std_logic;

    signal capture_addr : std_logic_vector(14 downto 0);
    signal frame_addr   : std_logic_vector(14 downto 0);
    signal capture_data : std_logic_vector(11 downto 0);
    signal capture_we   : std_logic;
    signal live_doutb   : std_logic_vector(11 downto 0);

    signal capture_col : std_logic_vector(7 downto 0);
    signal capture_row : std_logic_vector(6 downto 0);


    --------------------------------------------------------------------
    -- VGA
    --------------------------------------------------------------------
    signal vga_h_count    : std_logic_vector(9 downto 0);
    signal vga_v_count    : std_logic_vector(9 downto 0);
    signal selected_pixel : std_logic_vector(11 downto 0);
    signal in_stored_box  : std_logic;


    --------------------------------------------------------------------
    -- Stored 28x28 camera image BRAM
    --------------------------------------------------------------------
    signal stored_doutb        : std_logic_vector(7 downto 0);
    signal stored_addr_read    : unsigned(9 downto 0)
        := (others => '0');

    signal addr_to_stored_bram : std_logic_vector(9 downto 0);

    signal wea_stored_vec :
        std_logic_vector(0 downto 0)
        := "0";


    --------------------------------------------------------------------
    -- Button / freeze control
    --------------------------------------------------------------------
    signal btn_cap_debounced : std_logic;

    signal btn_cap_sync :
        std_logic_vector(2 downto 0)
        := (others => '0');

    signal btn_armed :
        std_logic
        := '1';

    signal freeze_request_toggle :
        std_logic
        := '0';

    signal freeze_req_sync_pclk :
        std_logic_vector(2 downto 0)
        := (others => '0');

    signal freeze_pending_pclk :
        std_logic
        := '0';

    signal freeze_stored_pclk :
        std_logic
        := '0';


    --------------------------------------------------------------------
    -- Synchronize frozen-image status into clk25 domain
    --------------------------------------------------------------------
    signal freeze_sync_clk25 :
        std_logic_vector(2 downto 0)
        := (others => '0');

    signal freeze_stored_clk25 :
        std_logic
        := '0';


    --------------------------------------------------------------------
    -- Stable ROI write
    --------------------------------------------------------------------
    signal roi_write_pending :
        std_logic
        := '0';

    signal roi_addr_reg :
        unsigned(9 downto 0)
        := (others => '0');

    signal roi_data_reg :
        std_logic_vector(7 downto 0)
        := (others => '0');


    --------------------------------------------------------------------
    -- Cloud mailbox interface
    --------------------------------------------------------------------
    signal mailbox_en_reg :
        std_logic
        := '0';

    signal mailbox_we_reg :
        std_logic_vector(3 downto 0)
        := (others => '0');

    signal mailbox_addr_reg :
        std_logic_vector(31 downto 0)
        := (others => '0');

    signal mailbox_din_reg :
        std_logic_vector(31 downto 0)
        := (others => '0');


    --------------------------------------------------------------------
    -- Live cloud inference mailbox state machine
    --------------------------------------------------------------------
    type mailbox_state_type is (

        MB_IDLE,

        MB_SET_ADDR,
        MB_WAIT_BRAM,
        MB_CAPTURE,
        MB_WRITE_WORD,

        MB_WRITE_IMAGE_INDEX,
        MB_WRITE_EXPECTED,
        MB_WRITE_STATUS,
        MB_WRITE_STATUS_HOLD,

        MB_STATUS_ADDR,
        MB_STATUS_WAIT,
        MB_STATUS_CHECK,

        MB_RESULT_ADDR,
        MB_RESULT_WAIT,
        MB_RESULT_CAPTURE,

        MB_CLEAR_STATUS,
        MB_DONE
    );

    signal mailbox_state :
        mailbox_state_type
        := MB_IDLE;


    --------------------------------------------------------------------
    -- Stored-image scan
    --------------------------------------------------------------------
    signal mailbox_pixel_index :
        integer range 0 to 783
        := 0;

    signal mailbox_word_index :
        integer range 0 to 195
        := 0;

    signal mailbox_byte_index :
        integer range 0 to 3
        := 0;

    signal mailbox_word_buffer :
        std_logic_vector(31 downto 0)
        := (others => '0');

    signal mailbox_owns_stored_bram :
        std_logic
        := '0';


    --------------------------------------------------------------------
    -- Returned cloud prediction
    --------------------------------------------------------------------
    signal cloud_result_latch :
        std_logic_vector(3 downto 0)
        := (others => '0');

    signal cloud_result_valid :
        std_logic
        := '0';


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
    -- clk50:
    -- button toggles freeze request
    --------------------------------------------------------------------
    process(clk50)
    begin

        if rising_edge(clk50) then

            btn_cap_sync <=
                btn_cap_sync(1 downto 0) &
                btn_cap_debounced;


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
    -- Camera clock domain:
    -- capture stable 28x28 thresholded image
    --------------------------------------------------------------------
    process(buffered_pclk)

        variable c_int        : integer;
        variable r_int        : integer;
        variable roi_addr_int : integer;

    begin

        if rising_edge(buffered_pclk) then

            c_int :=
                to_integer(
                    unsigned(capture_col)
                );

            r_int :=
                to_integer(
                    unsigned(capture_row)
                );


            wea_stored_vec <= "0";


            --------------------------------------------------------------
            -- Complete pending stored-BRAM write
            --------------------------------------------------------------
            if roi_write_pending = '1' then

                wea_stored_vec <= "1";

                roi_write_pending <= '0';

            end if;


            --------------------------------------------------------------
            -- Synchronize freeze request
            --------------------------------------------------------------
            freeze_req_sync_pclk <=
                freeze_req_sync_pclk(1 downto 0) &
                freeze_request_toggle;


            if freeze_req_sync_pclk(2) /=
               freeze_req_sync_pclk(1) then

                if freeze_stored_pclk = '1' then

                    ------------------------------------------------------
                    -- Unfreeze immediately
                    ------------------------------------------------------
                    freeze_stored_pclk <= '0';

                    freeze_pending_pclk <= '0';

                else

                    ------------------------------------------------------
                    -- Freeze after current ROI finishes
                    ------------------------------------------------------
                    freeze_pending_pclk <= '1';

                end if;

            end if;


            --------------------------------------------------------------
            -- Capture only while image is not frozen
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
                        to_unsigned(
                            roi_addr_int,
                            10
                        );


                    ------------------------------------------------------
                    -- MNIST-style binary threshold
                    ------------------------------------------------------
                    if capture_data(11 downto 8) > x"7" then

                        roi_data_reg <= x"7F";

                    else

                        roi_data_reg <= x"00";

                    end if;


                    roi_write_pending <= '1';


                    ------------------------------------------------------
                    -- Freeze only after the last ROI sample
                    ------------------------------------------------------
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
    -- Stored-thumbnail region on VGA
    --------------------------------------------------------------------
    in_stored_box <=
        '1'
        when
            (unsigned(vga_h_count) >= 300 and
             unsigned(vga_h_count) < 328) and

            (unsigned(vga_v_count) >= 200 and
             unsigned(vga_v_count) < 228)

        else
            '0';


    --------------------------------------------------------------------
    -- Synchronize frozen-image state into clk25 domain
    --------------------------------------------------------------------
    process(clk25)
    begin

        if rising_edge(clk25) then

            freeze_sync_clk25 <=
                freeze_sync_clk25(1 downto 0) &
                freeze_stored_pclk;

            freeze_stored_clk25 <=
                freeze_sync_clk25(2);

        end if;

    end process;


    --------------------------------------------------------------------
    -- Determine ownership of stored BRAM read port
    --
    -- Mailbox owns the BRAM only while copying the frozen image.
    -- VGA owns it at all other times.
    --------------------------------------------------------------------
    mailbox_owns_stored_bram <=
        '1'
        when
            mailbox_state = MB_SET_ADDR or
            mailbox_state = MB_WAIT_BRAM or
            mailbox_state = MB_CAPTURE or
            mailbox_state = MB_WRITE_WORD
        else
            '0';


    --------------------------------------------------------------------
    -- Stored BRAM Port B address multiplexer
    --------------------------------------------------------------------
    addr_to_stored_bram <=

        std_logic_vector(
            to_unsigned(
                mailbox_pixel_index,
                10
            )
        )
        when mailbox_owns_stored_bram = '1'

        else

        std_logic_vector(
            stored_addr_read
        );


    --------------------------------------------------------------------
    -- VGA stored-image read address
    --------------------------------------------------------------------
    process(clk25)
    begin

        if rising_edge(clk25) then

            --------------------------------------------------------------
            -- Do not modify VGA read pointer while mailbox owns BRAM.
            --------------------------------------------------------------
            if mailbox_owns_stored_bram = '0' then

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

        end if;

    end process;


    --------------------------------------------------------------------
    -- LIVE CAMERA -> CLOUD mailbox controller
    --
    -- Workflow:
    --
    -- 1. User captures/freezes a complete 28x28 camera image.
    -- 2. User raises sw_view_stored.
    -- 3. Frozen BRAM contents are copied into shared mailbox.
    -- 4. STATUS = 1 tells ARM a live image is ready.
    -- 5. ARM sends image to Cloud Run.
    -- 6. ARM writes RESULT and STATUS = 2.
    -- 7. Returned prediction is latched on LEDs.
    -- 8. Lower switch to re-arm another inference.
    --------------------------------------------------------------------
    process(clk25)
    begin

        if rising_edge(clk25) then

            --------------------------------------------------------------
            -- Default mailbox BRAM controls
            --------------------------------------------------------------
            mailbox_en_reg <= '0';

            mailbox_we_reg <= "0000";


            case mailbox_state is


                ----------------------------------------------------------
                -- Wait for:
                --
                --   frozen camera frame AND switch high
                ----------------------------------------------------------
                when MB_IDLE =>

                    if sw_view_stored = '0' then

                        cloud_result_valid <= '0';

                    end if;


                    if sw_view_stored = '1' and
                       freeze_stored_clk25 = '1' then

                        mailbox_pixel_index <= 0;

                        mailbox_word_index <= 0;

                        mailbox_byte_index <= 0;

                        mailbox_word_buffer <=
                            (others => '0');

                        cloud_result_valid <= '0';

                        mailbox_state <=
                            MB_SET_ADDR;

                    end if;


                ----------------------------------------------------------
                -- Present stored-BRAM address
                ----------------------------------------------------------
                when MB_SET_ADDR =>

                    mailbox_state <=
                        MB_WAIT_BRAM;


                ----------------------------------------------------------
                -- Wait for synchronous BRAM output
                ----------------------------------------------------------
                when MB_WAIT_BRAM =>

                    mailbox_state <=
                        MB_CAPTURE;


                ----------------------------------------------------------
                -- Capture one camera pixel
                ----------------------------------------------------------
                when MB_CAPTURE =>

                    case mailbox_byte_index is

                        when 0 =>

                            mailbox_word_buffer(
                                7 downto 0
                            ) <= stored_doutb;


                        when 1 =>

                            mailbox_word_buffer(
                                15 downto 8
                            ) <= stored_doutb;


                        when 2 =>

                            mailbox_word_buffer(
                                23 downto 16
                            ) <= stored_doutb;


                        when 3 =>

                            mailbox_word_buffer(
                                31 downto 24
                            ) <= stored_doutb;


                        when others =>

                            null;

                    end case;


                    if mailbox_byte_index = 3 then

                        mailbox_state <=
                            MB_WRITE_WORD;

                    else

                        mailbox_pixel_index <=
                            mailbox_pixel_index + 1;

                        mailbox_byte_index <=
                            mailbox_byte_index + 1;

                        mailbox_state <=
                            MB_SET_ADDR;

                    end if;


                ----------------------------------------------------------
                -- Write four camera pixels into mailbox
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
                -- Live deployment uses one image.
                --
                -- Image index = 0
                ----------------------------------------------------------
                when MB_WRITE_IMAGE_INDEX =>

                    mailbox_en_reg <= '1';

                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"00000314";

                    mailbox_din_reg <=
                        x"00000000";

                    mailbox_state <=
                        MB_WRITE_EXPECTED;


                ----------------------------------------------------------
                -- No ground-truth label exists for a live camera image.
                --
                -- 0xFF marks "unknown/not applicable".
                ----------------------------------------------------------
                when MB_WRITE_EXPECTED =>

                    mailbox_en_reg <= '1';

                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"0000031C";

                    mailbox_din_reg <=
                        x"000000FF";

                    mailbox_state <=
                        MB_WRITE_STATUS;


                ----------------------------------------------------------
                -- Tell ARM live image is ready
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
                -- Hold STATUS write for one complete BRAM clock
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
                -- Wait for synchronous mailbox BRAM read
                ----------------------------------------------------------
                when MB_STATUS_WAIT =>

                    mailbox_en_reg <= '1';

                    mailbox_we_reg <= "0000";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_state <=
                        MB_STATUS_CHECK;


                ----------------------------------------------------------
                -- Wait for ARM/cloud response
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
                -- Capture cloud prediction
                ----------------------------------------------------------
                when MB_RESULT_CAPTURE =>

                    cloud_result_latch <=
                        mailbox_doutb(3 downto 0);

                    cloud_result_valid <= '1';

                    mailbox_state <=
                        MB_CLEAR_STATUS;


                ----------------------------------------------------------
                -- Return STATUS to idle
                ----------------------------------------------------------
                when MB_CLEAR_STATUS =>

                    mailbox_en_reg <= '1';

                    mailbox_we_reg <= "1111";

                    mailbox_addr_reg <=
                        x"00000310";

                    mailbox_din_reg <=
                        x"00000000";

                    mailbox_state <=
                        MB_DONE;


                ----------------------------------------------------------
                -- Hold cloud result until switch is lowered.
                --
                -- Lowering the switch rearms the next live inference.
                ----------------------------------------------------------
                when MB_DONE =>

                    cloud_result_valid <= '1';

                    if sw_view_stored = '0' then

                        cloud_result_valid <= '0';

                        mailbox_state <=
                            MB_IDLE;

                    end if;


            end case;

        end if;

    end process;


    --------------------------------------------------------------------
    -- VGA pixel selection
    --------------------------------------------------------------------
    selected_pixel <=

        x"FFF"
        when
            sw_view_stored = '1' and
            in_stored_box = '1' and
            stored_doutb /= x"00"

        else

        x"000"
        when
            sw_view_stored = '1' and
            in_stored_box = '1'

        else

        x"222"
        when
            sw_view_stored = '1'

        else

        live_doutb;


    --------------------------------------------------------------------
    -- Live camera frame buffer
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
    -- Stored 28x28 camera image
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
    -- OV7670 controller
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
    -- OV7670 capture
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
    -- LED7    = valid cloud result returned
    -- LED6..4 = 0
    -- LED3..0 = predicted digit
    --
    -- Example:
    -- prediction 7 -> 10000111
    --------------------------------------------------------------------
    LED <=
        cloud_result_valid &
        "000" &
        cloud_result_latch;


end Behavioral;