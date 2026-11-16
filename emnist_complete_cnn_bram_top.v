`timescale 1ns/1ps
// ModelTest13: complete live-RAM CNN -> GAP -> signed FC47 -> argmax.
// Previous stage RTL unchanged. FC reads live, registered GAP output RAM;
// classifier weight and bias initialization is from the fixed quantized model.
module emnist_complete_cnn_bram_top (
 input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk,rst,start,
 input wire [5:0] score_read_addr,output reg [31:0] score_read_data,
 output wire conv1_finished,pool1_finished,conv2_finished,pool2_finished,
 output wire conv3_finished,gap_finished,fc_finished,
 output wire feature_overflow_seen,output wire fc_overflow_seen,
 output wire [5:0] predicted_class,output wire signed [31:0] predicted_score,
 output wire pool1_write_en,output wire [11:0] pool1_write_addr,output wire [7:0] pool1_write_data,
 output wire conv2_write_en,output wire [12:0] conv2_write_addr,output wire [7:0] conv2_write_data,
 output wire pool2_write_en,output wire [10:0] pool2_write_addr,output wire [7:0] pool2_write_data,
 output wire conv3_write_en,output wire [11:0] conv3_write_addr,output wire [7:0] conv3_write_data,
 output wire gap_write_en,output wire [5:0] gap_write_addr,output wire [7:0] gap_write_data,
 output wire score_write_en,output wire [5:0] score_write_addr,
 output wire [31:0] score_write_data
);
 wire [5:0] fc_input_addr;
 wire [7:0] fc_input_data;
 conv1_pool1_conv2_pool2_conv3_gap_bram_top front (
  .image_wr_clk(image_wr_clk), .image_wr_en(image_wr_en),
  .image_wr_addr(image_wr_addr), .image_wr_data(image_wr_data),
  .clk(clk),.rst(rst),.start(start),
  .read_addr(fc_input_addr),.read_data(fc_input_data),
  .conv1_finished(conv1_finished),.pool1_finished(pool1_finished),
  .conv2_finished(conv2_finished),.pool2_finished(pool2_finished),
  .conv3_finished(conv3_finished),.gap_finished(gap_finished),
  .overflow_seen(feature_overflow_seen),
  .pool1_write_en(pool1_write_en),.pool1_write_addr(pool1_write_addr),.pool1_write_data(pool1_write_data),
  .conv2_write_en(conv2_write_en),.conv2_write_addr(conv2_write_addr),.conv2_write_data(conv2_write_data),
  .pool2_write_en(pool2_write_en),.pool2_write_addr(pool2_write_addr),.pool2_write_data(pool2_write_data),
  .conv3_write_en(conv3_write_en),.conv3_write_addr(conv3_write_addr),.conv3_write_data(conv3_write_data),
  .gap_write_en(gap_write_en),.gap_write_addr(gap_write_addr),.gap_write_data(gap_write_data)
 );
 reg fc_launched;
 wire fc_start=gap_finished && !fc_launched;
 always @(posedge clk) begin
  if(rst) fc_launched<=1'b0;
  else if(fc_start) fc_launched<=1'b1;
 end
 (* rom_style="block" *) reg [7:0] fc_weights_rom [0:3007];
 (* rom_style="block" *) reg [31:0] fc_bias_rom [0:46];
 (* ram_style="block" *) reg [31:0] fc_scores_ram [0:46];
 initial begin
  $readmemh("fc_weights.mem",fc_weights_rom);
  $readmemh("fc_bias.mem",fc_bias_rom);
 end
 wire [11:0] fc_weight_addr;
 reg [7:0] fc_weight_data;
 wire [31:0] fc_bias_data=fc_bias_rom[score_write_addr];
 always @(posedge clk) begin
  fc_weight_data<=fc_weights_rom[fc_weight_addr];
  if(score_write_en) fc_scores_ram[score_write_addr]<=score_write_data;
  score_read_data<=fc_scores_ram[score_read_addr];
 end
 fc47_controller fc (
  .clk(clk),.rst(rst),.start(fc_start),
  .input_addr(fc_input_addr),.input_data(fc_input_data),
  .weight_addr(fc_weight_addr),.weight_data(fc_weight_data),.bias_data(fc_bias_data),
  .score_write_en(score_write_en),.score_write_addr(score_write_addr),
  .score_write_data(score_write_data),.finished(fc_finished),
  .predicted_class(predicted_class),.predicted_score(predicted_score),
  .overflow_seen(fc_overflow_seen)
 );
endmodule
