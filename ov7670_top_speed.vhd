library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.vcomponents.all;
use work.mnist_test_rom_pkg.all;

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
    -- NN state machine
    --------------------------------------------------------------------
   type nn_state_type is (
        NN_IDLE,
        NN_ADDR,
        NN_SEND,
        NN_WAIT_RESULT,
        NN_NEXT_IMAGE,
        NN_TEST_DONE
    );
    signal nn_state : nn_state_type := NN_IDLE;

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
    signal nn_scan_addr        : unsigned(9 downto 0) := (others => '0');
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
    -- zyNet scanner / result
    --------------------------------------------------------------------
    signal nn_data_in       : std_logic_vector(7 downto 0) := (others => '0');
    signal nn_valid_in      : std_logic := '0';
    signal nn_ready         : std_logic;
    signal nn_out           : std_logic_vector(31 downto 0);
    signal nn_out_valid     : std_logic;
    signal nn_intr          : std_logic;

    signal nn_running       : std_logic := '0';
    signal nn_scan_done     : std_logic := '0';
    signal nn_start_pending : std_logic := '0';
    signal nn_result_latch  : std_logic_vector(3 downto 0) := (others => '0');
    signal nn_out_seen      : std_logic := '0';

    signal params_loaded_debug : std_logic;
        --------------------------------------------------------------------
    -- Latency / throughput measurement
    --------------------------------------------------------------------
    signal latency_counter       : unsigned(31 downto 0) := (others => '0');
    signal latency_last_cycles   : unsigned(31 downto 0) := (others => '0');
    signal latency_min_cycles    : unsigned(31 downto 0) := (others => '1');
    signal latency_max_cycles    : unsigned(31 downto 0) := (others => '0');

    signal latency_sum_cycles    : unsigned(47 downto 0) := (others => '0');

    signal total_test_cycles     : unsigned(31 downto 0) := (others => '0');

    signal latency_active        : std_logic := '0';
    signal throughput_active     : std_logic := '0';
    signal total_test_cycles_latch : unsigned(31 downto 0) := (others => '0');
    --------------------------------------------------------------------
    -- Controlled MNIST accuracy test
    --------------------------------------------------------------------
    signal test_image_index : integer range 0 to MNIST_TEST_COUNT - 1 := 0;
    
    signal test_rom_address :
        integer range 0 to
        (MNIST_TEST_COUNT * MNIST_PIXELS_PER_IMAGE) - 1 := 0;
    
    signal correct_count : integer range 0 to MNIST_TEST_COUNT := 0;
    signal total_count   : integer range 0 to MNIST_TEST_COUNT := 0;
    
    signal accuracy_test_running : std_logic := '0';
    signal accuracy_test_done    : std_logic := '0';
    signal mnist_rom_addr : std_logic_vector(16 downto 0) := (others => '0');
    signal mnist_rom_dout : std_logic_vector(7 downto 0);
--        signal ila_nn_valid_vec  : std_logic_vector(0 downto 0);
 --   signal ila_scan_done_vec : std_logic_vector(0 downto 0);
 --   signal ila_out_valid_vec : std_logic_vector(0 downto 0);
 --   signal ila_freeze_vec    : std_logic_vector(0 downto 0);
    attribute mark_debug : string;

 attribute mark_debug of latency_last_cycles : signal is "true";
 attribute mark_debug of latency_min_cycles  : signal is "true";
 attribute mark_debug of latency_max_cycles  : signal is "true";
 attribute mark_debug of latency_sum_cycles  : signal is "true";
 attribute mark_debug of total_test_cycles   : signal is "true";
 attribute mark_debug of total_count         : signal is "true";
 attribute mark_debug of accuracy_test_done  : signal is "true";
 attribute mark_debug of total_test_cycles_latch : signal is "true";
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

    COMPONENT zyNet
        PORT (
            s_axi_aclk         : IN  std_logic;
            s_axi_aresetn      : IN  std_logic;
            axis_in_data       : IN  std_logic_vector(7 downto 0);
            axis_in_data_valid : IN  std_logic;
            axis_in_data_ready : OUT std_logic;

            s_axi_awaddr       : IN  std_logic_vector(4 downto 0);
            s_axi_awprot       : IN  std_logic_vector(2 downto 0);
            s_axi_awvalid      : IN  std_logic;
            s_axi_awready      : OUT std_logic;
            s_axi_wdata        : IN  std_logic_vector(31 downto 0);
            s_axi_wstrb        : IN  std_logic_vector(3 downto 0);
            s_axi_wvalid       : IN  std_logic;
            s_axi_wready       : OUT std_logic;
            s_axi_bresp        : OUT std_logic_vector(1 downto 0);
            s_axi_bvalid       : OUT std_logic;
            s_axi_bready       : IN  std_logic;
            s_axi_araddr       : IN  std_logic_vector(4 downto 0);
            s_axi_arprot       : IN  std_logic_vector(2 downto 0);
            s_axi_arvalid      : IN  std_logic;
            s_axi_arready      : OUT std_logic;
            s_axi_rdata        : OUT std_logic_vector(31 downto 0);
            s_axi_rresp        : OUT std_logic_vector(1 downto 0);
            s_axi_rvalid       : OUT std_logic;
            s_axi_rready       : IN  std_logic;

            intr                : OUT std_logic;
            nn_out              : OUT std_logic_vector(31 downto 0);
            nn_out_valid        : OUT std_logic;
            params_loaded_debug : OUT std_logic
        );
    END COMPONENT;
    COMPONENT blk_mem_gen_mnist_test
        PORT (
            clka  : IN  std_logic;
            addra : IN  std_logic_vector(16 downto 0);
            douta : OUT std_logic_vector(7 downto 0)
        );
    END COMPONENT;
 --   COMPONENT ila_0
  --      PORT (
  --          clk    : IN STD_LOGIC;
  --          probe0 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
  --          probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
  --          probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
  --          probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
   --         probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
   --         probe5 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
   --         probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
   --         probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
   --     );
   -- END COMPONENT;
begin
--------------------------------------------------------------------
-- MNIST controlled test-data ROM
--------------------------------------------------------------------
mnist_test_rom : blk_mem_gen_mnist_test
    PORT MAP (
        clka  => clk25,
        addra => mnist_rom_addr,
        douta => mnist_rom_dout
    );
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

                    -- Camera-to-NN preprocessing test block
-- Option A: binary threshold, MNIST-style
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
    -- clk25 domain: display stored BRAM and run zyNet once when allowed
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    -- clk25 domain: controlled multi-image MNIST accuracy test
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
                ----------------------------------------------------------------
        -- Timing counters
        ----------------------------------------------------------------
        if latency_active = '1' then
            latency_counter <= latency_counter + 1;
        end if;

        if throughput_active = '1' then
            total_test_cycles <= total_test_cycles + 1;
        end if;
            ----------------------------------------------------------------
            -- Keep freeze synchronization for camera/VGA functionality,
            -- although the accuracy test does not depend on camera capture.
            ----------------------------------------------------------------
            freeze_sync_clk25 <=
                freeze_sync_clk25(1 downto 0) & freeze_stored_pclk;
    
            freeze_stored_clk25 <= freeze_sync_clk25(2);
            freeze_prev <= freeze_stored_clk25;
    
            ----------------------------------------------------------------
            -- Default NN input-valid low.
            -- NN_SEND asserts it for one clock cycle per pixel.
            ----------------------------------------------------------------
            nn_valid_in <= '0';
    
            ----------------------------------------------------------------
            -- Stored thumbnail read address for VGA display.
            -- This remains available, but it is not used as NN test input.
            ----------------------------------------------------------------
            if sw_view_stored = '0' then
                stored_addr_read <= (others => '0');
    
            elsif unsigned(vga_h_count) = 300 and
                  unsigned(vga_v_count) = 200 then
                stored_addr_read <= (others => '0');
    
            elsif in_stored_box = '1' then
                if stored_addr_read < 783 then
                    stored_addr_read <= stored_addr_read + 1;
                end if;
            end if;
    
            ----------------------------------------------------------------
            -- Controlled MNIST accuracy-test state machine
            ----------------------------------------------------------------
            case nn_state is
    
                ------------------------------------------------------------
                -- Wait for:
                --   1. zyNet parameters loaded
                --   2. switch moved to stored/test position
                ------------------------------------------------------------
                when NN_IDLE =>
    
                    nn_running   <= '0';
                    nn_scan_done <= '0';
    
                    if params_loaded_debug = '1' and
                       sw_view_stored = '1' and
                       accuracy_test_done = '0' then
    
                        test_image_index     <= 0;
                        correct_count        <= 0;
                        total_count          <= 0;
    
                        nn_scan_addr         <= (others => '0');
                        nn_result_latch      <= (others => '0');
                        nn_out_seen          <= '0';
    
                        accuracy_test_running <= '1';
                        accuracy_test_done    <= '0';
    
                        nn_state <= NN_ADDR;
                    end if;
                                            -- Reset timing measurements for a new 100-image run.
                    latency_counter     <= (others => '0');
                    latency_last_cycles <= (others => '0');
                    latency_min_cycles  <= (others => '1');
                    latency_max_cycles  <= (others => '0');
                    latency_sum_cycles  <= (others => '0');

                    total_test_cycles   <= (others => '0');

                    latency_active      <= '0';
                    throughput_active   <= '1';
    
    
                ------------------------------------------------------------
                -- Address/setup cycle.
                -- Maintains the same spacing used by the working scanner.
                ------------------------------------------------------------
                when NN_ADDR =>
    
                    nn_running <= '1';
                    nn_state   <= NN_SEND;
    
    
                ------------------------------------------------------------
                -- Send one pixel from the local MNIST ROM.
                ------------------------------------------------------------
                when NN_SEND =>
    
                    nn_running  <= '1';
                        -- Start latency timing when the first pixel of
                    -- each image is launched toward zyNet.
                    if nn_scan_addr = 0 then
                        latency_counter <= (others => '0');
                        latency_active  <= '1';
                    end if;
                    nn_data_in <= mnist_rom_dout;
                    nn_valid_in <= '1';
    
                    if nn_scan_addr < 783 then
    
                        nn_scan_addr <= nn_scan_addr + 1;
                        nn_state     <= NN_ADDR;
    
                    else
    
                        -- All 784 pixels for this image have been sent.
                        nn_scan_addr <= (others => '0');
                        nn_running   <= '0';
                        nn_scan_done <= '1';
    
                        -- Do not start another image until zyNet returns
                        -- the classification for the current image.
                        nn_state <= NN_WAIT_RESULT;
    
                    end if;
    
    
                ------------------------------------------------------------
                -- Wait for zyNet classification and score it.
                ------------------------------------------------------------
                when NN_WAIT_RESULT =>
                
                    nn_running <= '0';
                
                    if nn_out_valid = '1' then
                
                        nn_result_latch <= nn_out(3 downto 0);
                        nn_out_seen     <= '1';
                
                        total_count <= total_count + 1;
                
                        if nn_out(3 downto 0) =
                           MNIST_LABEL_ROM(test_image_index) then
                
                            correct_count <= correct_count + 1;
                
                        end if;
                
                        ----------------------------------------------------
                        -- Capture completed-image latency
                        ----------------------------------------------------
                        latency_last_cycles <= latency_counter + 1;
                        latency_active      <= '0';
                
                        latency_sum_cycles <=
                            latency_sum_cycles +
                            resize(latency_counter + 1,
                                   latency_sum_cycles'length);
                
                        if (latency_counter + 1) < latency_min_cycles then
                            latency_min_cycles <= latency_counter + 1;
                        end if;
                
                        if (latency_counter + 1) > latency_max_cycles then
                            latency_max_cycles <= latency_counter + 1;
                        end if;
                
                        ----------------------------------------------------
                        -- Stop throughput timer on final image
                        ----------------------------------------------------
                        if test_image_index = MNIST_TEST_COUNT - 1 then
                            throughput_active       <= '0';
                            total_test_cycles_latch <= total_test_cycles + 1;
                        end if;
                
                        nn_state <= NN_NEXT_IMAGE;
                
                    end if;
    
    
                ------------------------------------------------------------
                -- Advance to next MNIST test image.
                ------------------------------------------------------------
                when NN_NEXT_IMAGE =>
    
                    nn_scan_done <= '0';
    
                    if test_image_index < MNIST_TEST_COUNT - 1 then
    
                        test_image_index <= test_image_index + 1;
                        nn_scan_addr     <= (others => '0');
    
                        nn_state <= NN_ADDR;
    
                    else
    
                        accuracy_test_running <= '0';
                        accuracy_test_done    <= '1';
    
                        nn_state <= NN_TEST_DONE;
    
                    end if;
    
    
                ------------------------------------------------------------
                -- Test complete.
                --
                -- Leave results latched until switch returns to 0.
                -- Returning switch to 0 rearms test for another run.
                ------------------------------------------------------------
                when NN_TEST_DONE =>
    
                    nn_running  <= '0';
                    nn_valid_in <= '0';
    
                    if sw_view_stored = '0' then
    
                        accuracy_test_done <= '0';
                        nn_out_seen        <= '0';
                        nn_scan_done       <= '0';
    
                        nn_state <= NN_IDLE;
    
                    end if;
    
            end case;
    
        end if;
    end process;
    mnist_rom_addr <= std_logic_vector(to_unsigned(test_rom_address, 17));
test_rom_address <=
        (test_image_index * MNIST_PIXELS_PER_IMAGE)
        + to_integer(nn_scan_addr);
    --------------------------------------------------------------------
    -- Stored BRAM read mux
    -- VGA owns read port while sw_view_stored = 1.
    -- NN owns read port while sw_view_stored = 0.
    --------------------------------------------------------------------
    addr_to_stored_bram <= std_logic_vector(stored_addr_read)
                           when sw_view_stored = '1'
                           else std_logic_vector(nn_scan_addr);

    --------------------------------------------------------------------
    -- VGA pixel mux
    --------------------------------------------------------------------
   selected_pixel <= x"FFF"
                      when (sw_view_stored = '1' and in_stored_box = '1' and stored_doutb /= x"00") else
                      x"000"
                      when (sw_view_stored = '1' and in_stored_box = '1') else
                      x"222"
                      when (sw_view_stored = '1') else
                      live_doutb;

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
    -- zyNet
    --------------------------------------------------------------------
    Inst_zyNet : zyNet
        PORT MAP (
            s_axi_aclk         => clk25,
            s_axi_aresetn      => '1',

            axis_in_data       => nn_data_in,
            axis_in_data_valid => nn_valid_in,
            axis_in_data_ready => nn_ready,

            s_axi_awaddr       => (others => '0'),
            s_axi_awprot       => (others => '0'),
            s_axi_awvalid      => '0',
            s_axi_awready      => open,

            s_axi_wdata        => (others => '0'),
            s_axi_wstrb        => (others => '0'),
            s_axi_wvalid       => '0',
            s_axi_wready       => open,

            s_axi_bresp        => open,
            s_axi_bvalid       => open,
            s_axi_bready       => '0',

            s_axi_araddr       => (others => '0'),
            s_axi_arprot       => (others => '0'),
            s_axi_arvalid      => '0',
            s_axi_arready      => open,

            s_axi_rdata        => open,
            s_axi_rresp        => open,
            s_axi_rvalid       => open,
            s_axi_rready       => '0',

            intr                => nn_intr,
            nn_out              => nn_out,
            nn_out_valid        => nn_out_valid,
            params_loaded_debug => params_loaded_debug
        );
--    Inst_ila_0 : ila_0
 --           PORT MAP (
  --              clk    => clk25,
    
  --              probe0 => std_logic_vector(nn_scan_addr), -- 10-bit address
  --              probe1 => stored_doutb,                   -- stored BRAM output
  --              probe2 => nn_data_in,                     -- actual NN input
  --              probe3 => ila_nn_valid_vec,               -- NN valid
  --              probe4 => ila_scan_done_vec,              -- scan complete
  --              probe5 => nn_out(3 downto 0),             -- NN predicted digit
  --              probe6 => ila_out_valid_vec,              -- NN output valid
  --              probe7 => ila_freeze_vec                  -- frozen state
  --          );
    --------------------------------------------------------------------
    -- LEDs
    --------------------------------------------------------------------
   --------------------------------------------------------------------
    -- Accuracy-test LEDs
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    -- Accuracy-test LEDs
    --
    -- During test:
    --   LED0 = parameters loaded
    --   LED1 = test running
    --   LED2 = result received
    --
    -- After test:
    --   LED7..0 = total correct classifications in binary
    --------------------------------------------------------------------
    LED <= std_logic_vector(to_unsigned(correct_count, 8))
           when accuracy_test_done = '1'
           else
           "00000" & nn_out_seen & accuracy_test_running & params_loaded_debug;

end Behavioral;