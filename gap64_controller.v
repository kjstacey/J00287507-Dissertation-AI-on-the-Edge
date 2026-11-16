`timescale 1ns/1ps
// 64 channel x 7 x 7 global average pool, nonnegative uint8 arithmetic.
// Exactly matches reference: (sum_of_49+24)/49, integer division.
module gap64_controller (
 input wire clk, input wire rst, input wire start,
 output wire [11:0] source_addr, input wire [7:0] source_data,
 output wire write_en, output wire [5:0] write_addr, output wire [7:0] write_data,
 output reg finished
);
 localparam IDLE=2'd0, REQUEST=2'd1, CAPTURE=2'd2, EMIT=2'd3;
 reg [1:0] state;
 reg [5:0] channel;
 reg [5:0] pixel;
 reg [13:0] sum;
 assign source_addr = channel * 12'd49 + pixel;
 assign write_en = (state==EMIT);
 assign write_addr = channel;
 wire [13:0] rounded_sum = sum + 14'd24;
 wire [13:0] quotient = rounded_sum / 14'd49;
 assign write_data = quotient[7:0];
 always @(posedge clk) begin
  if (rst) begin
   state<=IDLE; channel<=0; pixel<=0; sum<=0; finished<=0;
  end else begin
   case(state)
    IDLE: if(start) begin channel<=0;pixel<=0;sum<=0;finished<=0;state<=REQUEST; end
    REQUEST: state<=CAPTURE; // source BRAM registers requested address at this edge
    CAPTURE: begin
     sum<=sum + {6'b0,source_data};
     if(pixel==6'd48) state<=EMIT;
     else begin pixel<=pixel+1'b1;state<=REQUEST;end
    end
    EMIT: begin // write_en active for this clock edge
     if(channel==6'd63) begin finished<=1'b1;state<=IDLE;end
     else begin channel<=channel+1'b1;pixel<=0;sum<=0;state<=REQUEST;end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
