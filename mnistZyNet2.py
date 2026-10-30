from zynet import zynet
from zynet import utils
import os

def genMnistZynet(dataWidth=8, sigmoidSize=5, weightIntSize=4, inputIntSize=1):
    # 1. Compile the NN RTL
    model = zynet.model()
    model.add(zynet.layer("flatten", 784))
    model.add(zynet.layer("Dense", 30, "sigmoid"))
    model.add(zynet.layer("Dense", 20, "sigmoid"))
    model.add(zynet.layer("Dense", 10, "sigmoid"))
    model.add(zynet.layer("Dense", 10, "hardmax"))

    weightArray = utils.genWeightArray("WeigntsAndBiases.txt")
    biasArray = utils.genBiasArray("WeigntsAndBiases.txt")

    model.compile(
        pretrained="Yes", weights=weightArray, biases=biasArray,
        dataWidth=dataWidth, weightIntSize=weightIntSize,
        inputIntSize=inputIntSize, sigmoidSize=sigmoidSize,
    )

    # 2. Generate Improved Tcl for Vivado 2018.1
    tcl_filename = "inject_zynq_zynet.tcl"
    with open(tcl_filename, "w") as f:
        def w(line): f.write(line + "\n")

        w('set folder_name "Mnist_Camera"')
        w('set xpr_files [glob -nocomplain "./$folder_name/*.xpr"]')
        w('if {[llength $xpr_files] == 0} { set xpr_files [glob -nocomplain *.xpr] }')
        w('open_project [lindex $xpr_files 0]')
        
        # Force Vivado to update the hierarchy
        w('set_property source_mgmt_mode All [current_project]')
        
        # Add the files and WAIT for the GUI/Index to catch up
        w('if {[file exists "./zynet"]} {')
        w('    add_files [glob ./zynet/*.vhd]')
        w('    update_compile_order -fileset sources_1')
        w('}')

        w('if {[get_files design_1.bd] == ""} { create_bd_design "design_1" } else { open_bd_design [get_files design_1.bd] }')

        # Zynq Setup
        w('if {[get_bd_cells processing_system7_0] == ""} {')
        w('    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0')
        w('    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" } [get_bd_cells processing_system7_0]')
        w('}')

        # THE FIX: Create the cell using the specific file reference if module ref fails
        w('update_module_reference design_1')
        w('create_bd_cell -type module -reference zynet_top zyNet_0')

        # Clock connection from Zynq to NN
        w('connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins zyNet_0/clk]')

        w('validate_bd_design')
        w('save_bd_design')
        w('puts "SUCCESS: ZyNet cell created in Block Design."')

    os.system(f"vivado -mode batch -source {tcl_filename}")

if __name__ == "__main__":
    genMnistZynet()