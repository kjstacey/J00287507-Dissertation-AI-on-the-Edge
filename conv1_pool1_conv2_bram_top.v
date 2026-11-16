`timescale 1ns/1ps
// ModelTest6: live hardware chain, single model-specific 28x28 image.
// Conv1 -> MaxPool1 BRAM -> Conv2 -> Conv2 output BRAM.
// The Conv2 input ROM in ModelTest5 is NOT present here.
module conv1_pool1_conv2_bram_top(
 input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk, rst, start,
 input wire [12:0] read_addr,
 output reg [7:0] read_data,
 output wire conv1_finished, pool_finished, conv2_finished,
 output wire overflow_seen,
 output wire pool_write_en,
 output wire [11:0] pool_write_addr,
 output wire [7:0] pool_write_data,
 output wire conv2_write_en,
 output wire [12:0] conv2_write_addr,
 output wire [7:0] conv2_write_data
);
 wire [11:0] conv2_source_addr;
 wire [7:0] conv2_source_data;
 wire conv1_overflow, conv2_overflow;
 // Pool RAM is the SAME one written by MaxPool1. Its read port is
 // synchronous and is driven by Conv2's source address.
 conv1_pool1_bram_top front(
  .image_wr_clk(image_wr_clk), .image_wr_en(image_wr_en),
  .image_wr_addr(image_wr_addr), .image_wr_data(image_wr_data),
  .clk(clk),.rst(rst),.start(start),
  .pool_read_addr(conv2_source_addr),.pool_read_data(conv2_source_data),
  .conv1_finished(conv1_finished),.pool_finished(pool_finished),
  .overflow_seen(conv1_overflow),
  .pool_write_en(pool_write_en),.pool_write_addr(pool_write_addr),
  .pool_write_data(pool_write_data)
 );
 reg signed [7:0] weight_data;
 reg signed [31:0] bias_data;
 wire [12:0] weight_addr;
 wire [4:0] bias_addr;
 (* rom_style="block" *) reg [7:0] weight_rom [0:4607];
 (* rom_style="block" *) reg [31:0] bias_rom [0:31];
 localparam [31:0] CONV2_MULTIPLIER_Q24 = 32'h000128CE;
 (* ram_style="block" *) reg [7:0] output_ram [0:6271];
 initial begin
  $readmemh("weights2.mem",weight_rom);
  $readmemh("bias2.mem",bias_rom);
 end
 always @(posedge clk) begin
  weight_data <= weight_rom[weight_addr];
  bias_data <= bias_rom[bias_addr];
  if(conv2_write_en) output_ram[conv2_write_addr] <= conv2_write_data;
  read_data <= output_ram[read_addr];
 end
 conv2_controller_sync conv2(
  .clk(clk),.rst(rst),.start(pool_finished),
  .source_addr(conv2_source_addr),.source_data(conv2_source_data),
  .weight_addr(weight_addr),.weight_data(weight_data),
  .bias_addr(bias_addr),.bias_data(bias_data),
  .multiplier_q24(CONV2_MULTIPLIER_Q24),
  .out_valid(conv2_write_en),.out_addr(conv2_write_addr),
  .out_data(conv2_write_data),.finished(conv2_finished),
  .overflow_seen(conv2_overflow)
 );
 assign overflow_seen=conv1_overflow | conv2_overflow;
endmodule
