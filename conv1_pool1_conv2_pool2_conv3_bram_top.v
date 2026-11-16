`timescale 1ns/1ps
// ModelTest9: Live Conv1->Pool1->Conv2->Pool2->Conv3 chain.
// Reuses the verified ModelTest7 front end and ModelTest8 Conv3 controller/MAC.
// All source activations for Conv3 come from MaxPool2's writable BRAM, NOT a ROM.
module conv1_pool1_conv2_pool2_conv3_bram_top(
 input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk, rst, start,
 input wire [11:0] read_addr, output reg [7:0] read_data,
 output wire conv1_finished, pool1_finished, conv2_finished, pool2_finished, conv3_finished,
 output wire overflow_seen,
 output wire pool1_write_en, output wire [11:0] pool1_write_addr, output wire [7:0] pool1_write_data,
 output wire conv2_write_en, output wire [12:0] conv2_write_addr, output wire [7:0] conv2_write_data,
 output wire pool2_write_en, output wire [10:0] pool2_write_addr, output wire [7:0] pool2_write_data,
 output wire conv3_write_en, output wire [11:0] conv3_write_addr, output wire [7:0] conv3_write_data
);
 wire [10:0] conv3_source_addr;
 wire [7:0] conv3_source_data;
 wire front_overflow,conv3_overflow;
 conv1_pool1_conv2_pool2_bram_top front(
  .image_wr_clk(image_wr_clk), .image_wr_en(image_wr_en),
  .image_wr_addr(image_wr_addr), .image_wr_data(image_wr_data),
  .clk(clk),.rst(rst),.start(start),
  .read_addr(conv3_source_addr),.read_data(conv3_source_data),
  .conv1_finished(conv1_finished),.pool1_finished(pool1_finished),
  .conv2_finished(conv2_finished),.pool2_finished(pool2_finished),
  .overflow_seen(front_overflow),
  .pool1_write_en(pool1_write_en),.pool1_write_addr(pool1_write_addr),.pool1_write_data(pool1_write_data),
  .conv2_write_en(conv2_write_en),.conv2_write_addr(conv2_write_addr),.conv2_write_data(conv2_write_data),
  .pool2_write_en(pool2_write_en),.pool2_write_addr(pool2_write_addr),.pool2_write_data(pool2_write_data)
 );
 wire [14:0] conv3_weight_addr;
 wire [5:0] conv3_bias_addr;
 reg signed [7:0] conv3_weight_data;
 reg signed [31:0] conv3_bias_data;
 (* rom_style="block" *) reg [7:0] conv3_weight_rom [0:18431];
 (* rom_style="block" *) reg [31:0] conv3_bias_rom [0:63];
 localparam [31:0] CONV3_MULTIPLIER_Q24 = 32'h000126AC;
 (* ram_style="block" *) reg [7:0] conv3_output_ram [0:3135];
 initial begin
  $readmemh("weights3.mem",conv3_weight_rom);
  $readmemh("bias3.mem",conv3_bias_rom);
 end
 always @(posedge clk) begin
  conv3_weight_data <= conv3_weight_rom[conv3_weight_addr];
  conv3_bias_data <= conv3_bias_rom[conv3_bias_addr];
  if (conv3_write_en) conv3_output_ram[conv3_write_addr] <= conv3_write_data;
  read_data <= conv3_output_ram[read_addr];
 end
 conv3_controller_sync conv3(
  .clk(clk),.rst(rst),.start(pool2_finished),
  .source_addr(conv3_source_addr),.source_data(conv3_source_data),
  .weight_addr(conv3_weight_addr),.weight_data(conv3_weight_data),
  .bias_addr(conv3_bias_addr),.bias_data(conv3_bias_data),
  .multiplier_q24(CONV3_MULTIPLIER_Q24),
  .out_valid(conv3_write_en),.out_addr(conv3_write_addr),.out_data(conv3_write_data),
  .finished(conv3_finished),.overflow_seen(conv3_overflow)
 );
 assign overflow_seen = front_overflow | conv3_overflow;
endmodule
