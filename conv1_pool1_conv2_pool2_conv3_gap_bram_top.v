`timescale 1ns/1ps
// ModelTest11: live Conv1 -> Pool1 -> Conv2 -> Pool2 -> Conv3 -> GAP.
// GAP reads the actual writable Conv3 output RAM; no Conv3 reference ROM is
// used in the synthesized datapath. GAP is triggered when Conv3 finishes.
module conv1_pool1_conv2_pool2_conv3_gap_bram_top (
 input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk, rst, start,
 input wire [5:0] read_addr, output reg [7:0] read_data,
 output wire conv1_finished, pool1_finished, conv2_finished, pool2_finished, conv3_finished, gap_finished,
 output wire overflow_seen,
 output wire pool1_write_en, output wire [11:0] pool1_write_addr, output wire [7:0] pool1_write_data,
 output wire conv2_write_en, output wire [12:0] conv2_write_addr, output wire [7:0] conv2_write_data,
 output wire pool2_write_en, output wire [10:0] pool2_write_addr, output wire [7:0] pool2_write_data,
 output wire conv3_write_en, output wire [11:0] conv3_write_addr, output wire [7:0] conv3_write_data,
 output wire gap_write_en, output wire [5:0] gap_write_addr, output wire [7:0] gap_write_data
);
 wire [11:0] gap_source_addr;
 wire [7:0] gap_source_data;
 conv1_pool1_conv2_pool2_conv3_bram_top front (
  .image_wr_clk(image_wr_clk), .image_wr_en(image_wr_en),
  .image_wr_addr(image_wr_addr), .image_wr_data(image_wr_data),
  .clk(clk),.rst(rst),.start(start),
  .read_addr(gap_source_addr),.read_data(gap_source_data),
  .conv1_finished(conv1_finished),.pool1_finished(pool1_finished),
  .conv2_finished(conv2_finished),.pool2_finished(pool2_finished),
  .conv3_finished(conv3_finished),.overflow_seen(overflow_seen),
  .pool1_write_en(pool1_write_en),.pool1_write_addr(pool1_write_addr),.pool1_write_data(pool1_write_data),
  .conv2_write_en(conv2_write_en),.conv2_write_addr(conv2_write_addr),.conv2_write_data(conv2_write_data),
  .pool2_write_en(pool2_write_en),.pool2_write_addr(pool2_write_addr),.pool2_write_data(pool2_write_data),
  .conv3_write_en(conv3_write_en),.conv3_write_addr(conv3_write_addr),.conv3_write_data(conv3_write_data)
 );
 reg gap_launched;
 wire gap_start = conv3_finished && !gap_launched;
 always @(posedge clk) begin
  if (rst) gap_launched <= 1'b0;
  else if (gap_start) gap_launched <= 1'b1;
 end
 gap64_controller gap (
  .clk(clk),.rst(rst),.start(gap_start),
  .source_addr(gap_source_addr),.source_data(gap_source_data),
  .write_en(gap_write_en),.write_addr(gap_write_addr),.write_data(gap_write_data),
  .finished(gap_finished)
 );
 (* ram_style="block" *) reg [7:0] gap_output_ram [0:63];
 always @(posedge clk) begin
  if (gap_write_en) gap_output_ram[gap_write_addr] <= gap_write_data;
  read_data <= gap_output_ram[read_addr];
 end
endmodule
