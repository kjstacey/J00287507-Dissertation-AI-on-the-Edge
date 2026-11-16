`timescale 1ns/1ps
// Compact CNN Conv1 sequential controller for synchronous input memories.
// Adds one read-clock stage per tap and one bias-fetch stage per output.
// This is deliberately a separate file: original conv1_controller.v remains unchanged.
module conv1_controller_sync(
    input wire clk, input wire rst, input wire start,
    output reg [9:0] image_addr, input wire [7:0] image_data,
    output reg [7:0] weight_addr, input wire signed [7:0] weight_data,
    output wire [3:0] bias_addr, input wire signed [31:0] bias_data,
    input wire [31:0] multiplier_q24,
    output wire out_valid, output wire [7:0] out_pixel,
    output wire [3:0] out_channel, output wire [4:0] out_y, output wire [4:0] out_x,
    output wire finished, output wire overflow_seen
);
    localparam S_IDLE=0, S_BIAS=1, S_START=2, S_FETCH=3,
               S_TERM=4, S_WAIT=5, S_OUTPUT=6, S_FINISH=7;
    reg [2:0] state;
    reg [3:0] channel;
    reg [4:0] y, x;
    reg [3:0] tap;
    reg overflow_any;
    reg padded;
    reg [5:0] image_row, image_col;
    reg fetched_pad; // delay padding indication to match synchronous ROM output
    wire term_valid = (state==S_TERM);
    wire core_start = (state==S_START);
    wire core_done;
    wire [7:0] core_out;
    wire signed [31:0] unused_accumulator;
    wire core_overflow;
    wire [7:0] pixel_in = fetched_pad ? 8'd0 : image_data;

    always @* begin
        image_row = {1'b0,y} + (tap / 3);
        image_col = {1'b0,x} + (tap % 3);
        padded = (image_row==0) || (image_row==29) ||
                 (image_col==0) || (image_col==29);
        image_addr = padded ? 10'd0 : (image_row-1)*28+(image_col-1);
        weight_addr = channel*9+tap;
    end
    assign bias_addr = channel;
    assign out_channel = channel;
    assign out_y = y;
    assign out_x = x;
    assign out_pixel = core_out;
    assign out_valid = (state==S_OUTPUT);
    assign finished = (state==S_FINISH);
    assign overflow_seen = overflow_any | core_overflow;

    conv3x3_mac_q24 mac(
        .clk(clk), .rst(rst), .start(core_start),
        .bias_q(bias_data), .multiplier_q24(multiplier_q24),
        .term_valid(term_valid), .activation_u8(pixel_in), .weight_s8(weight_data),
        .done(core_done), .activation_out(core_out),
        .accumulator_out(unused_accumulator), .overflow(core_overflow)
    );

    always @(posedge clk) begin
        if (rst) begin
            state<=S_IDLE; channel<=0; y<=0; x<=0;
            tap<=0; fetched_pad<=1'b0; overflow_any<=1'b0;
        end else begin
            case (state)
                S_IDLE: if (start) begin
                    channel<=0; y<=0; x<=0; tap<=0; overflow_any<=0;
                    state<=S_BIAS;
                end
                S_BIAS: state<=S_START; // synchronous bias ROM captures address
                S_START: begin tap<=0; state<=S_FETCH; end
                S_FETCH: begin
                    fetched_pad<=padded; // match the pixel captured by ROM
                    state<=S_TERM;
                end
                S_TERM: if (tap==8) state<=S_WAIT;
                        else begin tap<=tap+1'b1; state<=S_FETCH; end
                S_WAIT: if (core_done) begin
                    overflow_any<=overflow_any|core_overflow;
                    state<=S_OUTPUT;
                end
                S_OUTPUT: begin
                    if (x==27) begin
                        x<=0;
                        if (y==27) begin
                            y<=0;
                            if (channel==15) state<=S_FINISH;
                            else begin channel<=channel+1'b1; state<=S_BIAS; end
                        end else begin y<=y+1'b1; state<=S_BIAS; end
                    end else begin x<=x+1'b1; state<=S_BIAS; end
                end
                S_FINISH: if (!start) state<=S_IDLE;
                default: state<=S_IDLE;
            endcase
        end
    end
endmodule
