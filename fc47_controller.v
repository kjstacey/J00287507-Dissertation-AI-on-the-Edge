`timescale 1ns/1ps
// Final 64 -> 47 dense classifier. uint8 GAP feature x signed int8 weight,
// signed int32 bias, signed int32 unscaled logit. Argmax breaks ties to lower index.
module fc47_controller(
 input wire clk, input wire rst, input wire start,
 output wire [5:0] input_addr, input wire [7:0] input_data,
 output wire [11:0] weight_addr, input wire [7:0] weight_data,
 input wire [31:0] bias_data,
 output wire score_write_en, output wire [5:0] score_write_addr,
 output wire [31:0] score_write_data,
 output reg finished, output reg [5:0] predicted_class,
 output reg signed [31:0] predicted_score,
 output reg overflow_seen
);
 localparam IDLE=2'd0, REQUEST=2'd1, CAPTURE=2'd2, EMIT=2'd3;
 reg [1:0] state;
 reg [5:0] class_idx, feature_idx;
 reg signed [39:0] sum;
 reg best_valid;
 wire signed [8:0] act_signed=$signed({1'b0,input_data});
 wire signed [7:0] weight_signed=$signed(weight_data);
 wire signed [16:0] product=act_signed*weight_signed;
 wire signed [39:0] sum_plus_bias=sum+{{8{bias_data[31]}},bias_data};
 wire signed [31:0] score_sat=(sum_plus_bias>40'sd2147483647)?32'sh7fffffff:
  (sum_plus_bias < -40'sd2147483648)?32'sh80000000:sum_plus_bias[31:0];
 assign input_addr=feature_idx;
 assign weight_addr=class_idx*12'd64+feature_idx;
 assign score_write_en=(state==EMIT);
 assign score_write_addr=class_idx;
 assign score_write_data=score_sat;
 always @(posedge clk) begin
  if(rst) begin
   state<=IDLE;class_idx<=0;feature_idx<=0;sum<=0;finished<=0;
   best_valid<=0;predicted_class<=0;predicted_score<=0;overflow_seen<=0;
  end else case(state)
   IDLE: if(start) begin
    class_idx<=0;feature_idx<=0;sum<=0;finished<=0;best_valid<=0;
    predicted_class<=0;predicted_score<=0;overflow_seen<=0;state<=REQUEST;
   end
   REQUEST: state<=CAPTURE;
   CAPTURE: begin
    sum<=sum+{{23{product[16]}},product};
    if(feature_idx==6'd63) state<=EMIT;
    else begin feature_idx<=feature_idx+1'b1;state<=REQUEST;end
   end
   EMIT: begin
    if(sum_plus_bias>40'sd2147483647 || sum_plus_bias< -40'sd2147483648)
     overflow_seen<=1'b1;
    if(!best_valid || $signed(score_sat)>predicted_score) begin
     best_valid<=1'b1;predicted_class<=class_idx;predicted_score<=score_sat;
    end
    if(class_idx==6'd46) begin finished<=1'b1;state<=IDLE;end
    else begin class_idx<=class_idx+1'b1;feature_idx<=0;sum<=0;state<=REQUEST;end
   end
   default:state<=IDLE;
  endcase
 end
endmodule
