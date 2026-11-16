`timescale 1ns/1ps
// MaxPool2 2x2/stride 2, no padding, channel-major unsigned uint8.
// Source: 32 x 14 x 14, destination: 32 x 7 x 7.
// The source RAM has synchronous 1-cycle registered reads.
module maxpool2_controller(
    input wire clk, input wire rst, input wire start,
    output reg [12:0] src_addr, input wire [7:0] src_data,
    output wire write_en, output wire [10:0] write_addr,
    output wire [7:0] write_data, output wire finished
);
    localparam IDLE=3'd0, REQUEST=3'd1, READ_WAIT=3'd2,
               CAPTURE=3'd3, STORE=3'd4, FINISH=3'd5;
    reg [2:0] state;
    reg [4:0] channel;
    reg [2:0] y,x;
    reg [1:0] tap;
    reg [7:0] max_value;
    wire [3:0] source_y = {y,1'b0} + tap[1];
    wire [3:0] source_x = {x,1'b0} + tap[0];
    wire [12:0] source_offset = channel * 13'd196
                        + source_y * 13'd14 + source_x;
    assign write_en = (state == STORE);
    assign write_addr = channel * 11'd49 + y * 11'd7 + x;
    assign write_data = max_value;
    assign finished = (state == FINISH);
    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; channel<=0; y<=0; x<=0;
            tap<=0; src_addr<=0; max_value<=0;
        end else begin
            case (state)
                IDLE: if (start) begin
                    channel<=0; y<=0; x<=0; tap<=0;
                    max_value<=0; state<=REQUEST;
                end
                REQUEST: begin
                    src_addr<=source_offset;
                    state<=READ_WAIT;
                end
                READ_WAIT: state<=CAPTURE;
                CAPTURE: begin
                    if (tap==0 || src_data>max_value) max_value<=src_data;
                    if (tap==3) state<=STORE;
                    else begin tap<=tap+1'b1; state<=REQUEST; end
                end
                STORE: begin
                    tap<=0; max_value<=0;
                    if (x==6) begin
                        x<=0;
                        if (y==6) begin
                            y<=0;
                            if (channel==31) state<=FINISH;
                            else begin channel<=channel+1'b1; state<=REQUEST; end
                        end else begin y<=y+1'b1; state<=REQUEST; end
                    end else begin x<=x+1'b1; state<=REQUEST; end
                end
                FINISH: if (!start) state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
