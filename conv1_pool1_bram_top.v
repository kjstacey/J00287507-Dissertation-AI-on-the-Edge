`timescale 1ns/1ps
// Sequential hardware composition: verified Conv1 BRAM design, then MaxPool1.
// Conv1 input RAM is now written by the camera clock domain.
module conv1_pool1_bram_top(
    input wire image_wr_clk, image_wr_en,
 input wire [9:0] image_wr_addr,
 input wire [7:0] image_wr_data,
 input wire clk, input wire rst, input wire start,
    input wire [11:0] pool_read_addr,
    output reg [7:0] pool_read_data,
    output wire conv1_finished, output wire pool_finished,
    output wire overflow_seen,
    output wire pool_write_en,
    output wire [11:0] pool_write_addr,
    output wire [7:0] pool_write_data
);
    wire [13:0] conv1_read_addr;
    wire [7:0] conv1_read_data;
    wire unused_valid;
    wire [7:0] unused_pixel;
    wire [3:0] unused_channel;
    wire [4:0] unused_y, unused_x;

    conv1_bram_top conv1(
        .image_wr_clk(image_wr_clk), .image_wr_en(image_wr_en),
  .image_wr_addr(image_wr_addr), .image_wr_data(image_wr_data),
  .clk(clk), .rst(rst), .start(start),
        .read_addr(conv1_read_addr), .read_data(conv1_read_data),
        .finished(conv1_finished), .overflow_seen(overflow_seen),
        .out_valid(unused_valid), .out_pixel(unused_pixel),
        .out_channel(unused_channel), .out_y(unused_y), .out_x(unused_x)
    );

    maxpool1_controller pool1(
        .clk(clk), .rst(rst), .start(conv1_finished),
        .src_addr(conv1_read_addr), .src_data(conv1_read_data),
        .write_en(pool_write_en), .write_addr(pool_write_addr),
        .write_data(pool_write_data), .finished(pool_finished)
    );

    (* ram_style = "block" *) reg [7:0] pool_ram [0:3135];
    always @(posedge clk) begin
        if (pool_write_en) pool_ram[pool_write_addr] <= pool_write_data;
        pool_read_data <= pool_ram[pool_read_addr];
    end
endmodule
