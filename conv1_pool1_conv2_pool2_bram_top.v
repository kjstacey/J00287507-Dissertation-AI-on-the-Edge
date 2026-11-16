`timescale 1ns/1ps
// ModelTest7. Preserves the verified ModelTest6 hardware hierarchy and
// adds live MaxPool2 operating directly on the Conv2 output BRAM.
module conv1_pool1_conv2_pool2_bram_top(
 input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk, rst, start,
 input wire [10:0] read_addr,
 output reg [7:0] read_data,
 output wire conv1_finished, pool1_finished, conv2_finished, pool2_finished,
 output wire overflow_seen,
 output wire pool1_write_en, output wire [11:0] pool1_write_addr,
 output wire [7:0] pool1_write_data,
 output wire conv2_write_en, output wire [12:0] conv2_write_addr,
 output wire [7:0] conv2_write_data,
 output wire pool2_write_en, output wire [10:0] pool2_write_addr,
 output wire [7:0] pool2_write_data
);
 wire [12:0] pool2_source_addr;
 wire [7:0] pool2_source_data;
 conv1_pool1_conv2_bram_top front(
  .image_wr_clk(image_wr_clk), .image_wr_en(image_wr_en),
  .image_wr_addr(image_wr_addr), .image_wr_data(image_wr_data),
  .clk(clk),.rst(rst),.start(start),
  .read_addr(pool2_source_addr),.read_data(pool2_source_data),
  .conv1_finished(conv1_finished),.pool_finished(pool1_finished),
  .conv2_finished(conv2_finished),.overflow_seen(overflow_seen),
  .pool_write_en(pool1_write_en),.pool_write_addr(pool1_write_addr),
  .pool_write_data(pool1_write_data),
  .conv2_write_en(conv2_write_en),.conv2_write_addr(conv2_write_addr),
  .conv2_write_data(conv2_write_data)
 );
 maxpool2_controller pool2(
  .clk(clk),.rst(rst),.start(conv2_finished),
  .src_addr(pool2_source_addr),.src_data(pool2_source_data),
  .write_en(pool2_write_en),.write_addr(pool2_write_addr),
  .write_data(pool2_write_data),.finished(pool2_finished)
 );
 (* ram_style = "block" *) reg [7:0] pool2_ram [0:1567];
 always @(posedge clk) begin
  if (pool2_write_en) pool2_ram[pool2_write_addr] <= pool2_write_data;
  read_data <= pool2_ram[read_addr];
 end
endmodule
