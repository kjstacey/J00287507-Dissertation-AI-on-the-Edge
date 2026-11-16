`timescale 1ns/1ps
// Standalone compact Conv1 memory-integrated hardware top (25 MHz user clock).
// ROMs are synchronous; output RAM is synchronous-write/synchronous-read.
// Live image is supplied by the camera; weights and biases stay model-specific.
// Do not use this as the camera top or as a whole-CNN inference design.
module conv1_bram_top(
    input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk, input wire rst, input wire start,
    input wire [13:0] read_addr,
    output reg [7:0] read_data,
    output wire finished, output wire overflow_seen,
    output wire out_valid,
    output wire [7:0] out_pixel,
    output wire [3:0] out_channel,
    output wire [4:0] out_y, output wire [4:0] out_x
);
    wire [9:0] image_addr;
    wire [7:0] weight_addr;
    wire [3:0] bias_addr;
    reg [7:0] image_data;
    reg signed [7:0] weight_data;
    reg signed [31:0] bias_data;

    // Camera image memory: port A writes on camera PCLK; port B reads on clk25.
    (* ram_style = "block" *) reg [7:0] image_ram [0:783];
    (* rom_style = "block" *) reg [7:0] weights_rom [0:143];
    (* rom_style = "block" *) reg [31:0] bias_rom [0:15];
    localparam [31:0] CONV1_MULTIPLIER_Q24 = 32'h0000871A;
    (* ram_style = "block" *) reg [7:0] activation_ram [0:12543];

    // The memory files must also be present in the synthesis project (not
    // just the XSim working directory). The expected reference is TB-only.
    initial begin
        $readmemh("weights.mem", weights_rom);
        $readmemh("bias.mem", bias_rom);
    end
    always @(posedge image_wr_clk) begin
        if (image_wr_en) image_ram[image_wr_addr] <= image_wr_data;
    end

    // Values change just AFTER the rising edge, and the controller consumes
    // them at the FOLLOWING rising edge after its fetch state.
    always @(posedge clk) begin
        image_data <= image_ram[image_addr];
        weight_data <= weights_rom[weight_addr];
        bias_data <= bias_rom[bias_addr];
    end
    // output coordinates are channel-major, y-major, x-major
    wire [13:0] write_addr = out_channel*14'd784 + out_y*14'd28 + out_x;
    always @(posedge clk) begin
        if (out_valid) activation_ram[write_addr] <= out_pixel;
        read_data <= activation_ram[read_addr];
    end

    conv1_controller_sync controller(
        .clk(clk), .rst(rst), .start(start),
        .image_addr(image_addr), .image_data(image_data),
        .weight_addr(weight_addr), .weight_data(weight_data),
        .bias_addr(bias_addr), .bias_data(bias_data),
        .multiplier_q24(CONV1_MULTIPLIER_Q24),
        .out_valid(out_valid), .out_pixel(out_pixel),
        .out_channel(out_channel), .out_y(out_y), .out_x(out_x),
        .finished(finished), .overflow_seen(overflow_seen)
    );
endmodule
