from zynet import zynet
from zynet import utils
import os


def genMnistZynet(dataWidth=8, sigmoidSize=5, weightIntSize=4, inputIntSize=1):
    # ------------------------------------------------------------
    # 1. Compile the zyNet IP from pretrained weights/biases
    # ------------------------------------------------------------
    model = zynet.model()
    model.add(zynet.layer("flatten", 784))
    model.add(zynet.layer("Dense", 30, "sigmoid"))
    model.add(zynet.layer("Dense", 20, "sigmoid"))
    model.add(zynet.layer("Dense", 10, "sigmoid"))
    model.add(zynet.layer("Dense", 10, "hardmax"))

    weightArray = utils.genWeightArray("WeigntsAndBiases.txt")
    biasArray = utils.genBiasArray("WeigntsAndBiases.txt")

    model.compile(
        pretrained="Yes",
        weights=weightArray,
        biases=biasArray,
        dataWidth=dataWidth,
        weightIntSize=weightIntSize,
        inputIntSize=inputIntSize,
        sigmoidSize=sigmoidSize,
    )

    # ------------------------------------------------------------
    # 2. Camera source/config paths
    # ------------------------------------------------------------
    camera_path = "D:/Dissertation/CameraSourceFiles/"
    vhdl_files = [
        "F0UU05JILV7T644.vhd",
        "F5IR32HILV7T64J.vhd",
        "F6SJNRTILV7T642.vhd",
        "FLW9TWWILV7T64G.vhd",
        "FN0FBA2ILV7T649.vhd",
        "FNTSDZZILV7T645.vhd",
        "FQTSFQ5ILV7T63Z.vhd",
        "FZTEBUMILV7T646.vhd",
    ]
    xdc_file = "F5QMAYQILV7T6TF.xdc"

    # Optional: set this only if your Vivado install has the ZedBoard board files.
    board_part = "em.avnet.com:zed:part0:1.4"

    # ------------------------------------------------------------
    # 3. Generate master Tcl
    # ------------------------------------------------------------
    with open("build_all.tcl", "w", newline="\n") as f:
        def w(line=""):
            f.write(line + "\n")

        w('create_project Camera_MNIST ./Camera_MNIST -part xc7z020clg484-1 -force')

        # Try to set board part, but do not fail if board files are missing.
        w("catch {")
        w(f'    set_property board_part {board_part} [current_project]')
        w("}")

        # Add camera HDL files
        for file in vhdl_files:
            w(f'add_files -norecurse "{camera_path}{file}"')

        # Add zyNet-generated Verilog
        # Adjust these globs if your compile step outputs somewhere else.
        w('add_files -norecurse [glob -nocomplain ./src/fpga/rtl/*.v]')

        # Add constraints
        w(f'add_files -fileset constrs_1 -norecurse "{camera_path}{xdc_file}"')
        w("update_compile_order -fileset sources_1")

        # --------------------------------------------------------
        # Block design
        # --------------------------------------------------------
        w('create_bd_design "design_1"')

        # Processing system
        w('create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7')

        # Only apply board automation if the board_part exists
        w("if {[string length [get_property board_part [current_project]]] > 0} {")
        w('    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 '
          '-config {make_external "FIXED_IO, DDR" apply_board_preset "1" } [get_bd_cells ps7]')
        w("}")

        # --------------------------------------------------------
        # BRAM
        # FIX: Vivado 2018.1 does NOT accept Simple_Dual_Port_RAM here.
        # Use True_Dual_Port_RAM and use A as write, B as read.
        # --------------------------------------------------------
        w('create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0')
        w('set_property CONFIG.Interface_Type {Native} [get_bd_cells blk_mem_gen_0]')
        w('set_property CONFIG.Memory_Type {True_Dual_Port_RAM} [get_bd_cells blk_mem_gen_0]')
        w('set_property -dict [list \\')
        w('    CONFIG.Write_Width_A {8} \\')
        w('    CONFIG.Read_Width_A {8} \\')
        w('    CONFIG.Write_Depth_A {307200} \\')
        w('    CONFIG.Write_Width_B {8} \\')
        w('    CONFIG.Read_Width_B {8} \\')
        w('    CONFIG.Enable_B {Use_ENB_Pin} \\')
        w('    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \\')
        w('    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \\')
        w('] [get_bd_cells blk_mem_gen_0]')

        # --------------------------------------------------------
        # Module references
        # FIX: create module references directly.
        # Do NOT call update_module_reference before the cells exist.
        # --------------------------------------------------------
        w('create_bd_cell -type module -reference ov7670_top ov7670_top_0')
        w('create_bd_cell -type module -reference zyNet zyNet_0')

        # --------------------------------------------------------
        # Wiring that matches your original intent
        # NOTE:
        # These pin names assume the same ports you used before.
        # If one of your modules uses different names, Vivado will
        # report the exact pin that needs to be changed.
        # --------------------------------------------------------

        # Camera writes into BRAM port A
        w('connect_bd_net [get_bd_pins ov7670_top_0/data_out] [get_bd_pins blk_mem_gen_0/dina]')
        w('connect_bd_net [get_bd_pins ov7670_top_0/wr_en]    [get_bd_pins blk_mem_gen_0/wea]')
        w('connect_bd_net [get_bd_pins ov7670_top_0/addr_out] [get_bd_pins blk_mem_gen_0/addra]')

        # --------------------------------------------------------
        # Optional clock hookups:
        # Uncomment these only if these are your real port names.
        # Leaving them commented avoids hard-failing on the wrong names.
        # --------------------------------------------------------
        w('# connect_bd_net [get_bd_pins ov7670_top_0/pclk]     [get_bd_pins blk_mem_gen_0/clka]')
        w('# connect_bd_net [get_bd_pins zyNet_0/clk]           [get_bd_pins blk_mem_gen_0/clkb]')
        w('# connect_bd_net [get_bd_pins zyNet_0/addr_in]       [get_bd_pins blk_mem_gen_0/addrb]')
        w('# connect_bd_net [get_bd_pins blk_mem_gen_0/doutb]   [get_bd_pins zyNet_0/data_in]')
        w('# connect_bd_net [get_bd_pins ps7/FCLK_CLK0]         [get_bd_pins zyNet_0/clk]')

        # --------------------------------------------------------
        # Validate and wrap
        # --------------------------------------------------------
        w("update_compile_order -fileset sources_1")
        w("validate_bd_design")
        w("save_bd_design")
        w("regenerate_bd_layout")

        w('make_wrapper -files [get_files ./Camera_MNIST/Camera_MNIST.srcs/sources_1/bd/design_1/design_1.bd] -top')
        w('add_files -norecurse ./Camera_MNIST/Camera_MNIST.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v')
        w('set_property top design_1_wrapper [current_fileset]')
        w("update_compile_order -fileset sources_1")

    print("\n[COMPLETE] Generated build_all.tcl")
    print("Run:")
    print("    vivado -mode gui -source build_all.tcl")


if __name__ == "__main__":
    genMnistZynet()