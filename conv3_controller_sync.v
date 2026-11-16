`timescale 1ns/1ps
// Sequential Conv3: 32x7x7 -> 64x7x7, 3x3 pad 1; one 288-term MAC.
// Source/weight/bias ROM reads are synchronous, one 25 MHz clock latency.
// Outstream output address = out_channel * 49 + y * 7 + x.
module conv3_controller_sync(
 input wire clk, input wire rst, input wire start,
 output wire [10:0] source_addr, input wire [7:0] source_data,
 output wire [14:0] weight_addr, input wire signed [7:0] weight_data,
 output wire [5:0] bias_addr, input wire signed [31:0] bias_data,
 input wire [31:0] multiplier_q24,
 output wire out_valid, output wire [11:0] out_addr,
 output wire [7:0] out_data, output wire finished, output wire overflow_seen
);
 localparam IDLE=0, BIAS=1, START=2, FETCH=3, TERM=4, WAIT_MAC=5,
            OUTPUT=6, FINISHED=7;
 reg [2:0] state;
 reg [5:0] channel; // out channels 0..63
 reg [2:0] y,x;
 reg [8:0] tap; // 0..287, channel major, then kernel row and column
 reg fetched_pad;
 reg overflow_any;
 wire [5:0] src_channel = tap / 9;
 wire [3:0] kernel_tap = tap % 9;
 wire [3:0] padded_row = {1'b0,y} + kernel_tap/3;
 wire [3:0] padded_col = {1'b0,x} + kernel_tap%3;
 wire is_padding = (padded_row==0 || padded_col==0 || padded_row==8 || padded_col==8);
 assign source_addr = is_padding ? 11'd0 : src_channel*11'd49 + (padded_row-1)*11'd7 + (padded_col-1);
 assign weight_addr = channel*15'd288 + tap;
 assign bias_addr = channel;
 assign out_addr = channel*12'd49 + y*12'd7 + x;
 assign out_valid = state==OUTPUT;
 assign finished = state==FINISHED;
 wire core_done,core_overflow;
 wire [7:0] core_result;
 wire signed [31:0] unused_acc;
 assign out_data=core_result;
 assign overflow_seen=overflow_any | core_overflow;
 conv288_mac_q24 mac(
  .clk(clk), .rst(rst), .start(state==START), .bias_q(bias_data),
  .multiplier_q24(multiplier_q24), .term_valid(state==TERM),
  .activation_u8(fetched_pad?8'd0:source_data),.weight_s8(weight_data),
  .done(core_done), .activation_out(core_result),
  .accumulator_out(unused_acc),.overflow(core_overflow)
 );
 always @(posedge clk) begin
  if(rst) begin state<=IDLE;channel<=0;y<=0;x<=0;tap<=0;
     fetched_pad<=0; overflow_any<=0; end
  else case(state)
   IDLE: if(start) begin channel<=0;y<=0;x<=0;tap<=0;overflow_any<=0;state<=BIAS;end
   BIAS: state<=START; // ROM samples bias address
   START: begin tap<=0;state<=FETCH;end
   FETCH: begin fetched_pad<=is_padding;state<=TERM;end // ROMs sample addresses
   TERM: if(tap==287) state<=WAIT_MAC;
         else begin tap<=tap+1'b1;state<=FETCH;end
   WAIT_MAC: if(core_done) begin overflow_any<=overflow_any|core_overflow;state<=OUTPUT;end
   OUTPUT: if(x==6) begin x<=0;
            if(y==6) begin y<=0;
             if(channel==63) state<=FINISHED;
             else begin channel<=channel+1'b1;state<=BIAS;end
            end else begin y<=y+1'b1;state<=BIAS;end
           end else begin x<=x+1'b1;state<=BIAS;end
   FINISHED: if(!start) state<=IDLE;
   default: state<=IDLE;
  endcase
 end
endmodule
