`timescale 1ns/1ps
// Sequential 2x2 max pooling, stride 2, no padding.
// Source tensor: 16 x 28 x 28, channel-major.
// Destination:   16 x 14 x 14, channel-major.
// The source read port is a synchronous 1-cycle RAM with registered data.
module maxpool1_controller(
    input wire clk, input wire rst, input wire start,
    output reg [13:0] src_addr, input wire [7:0] src_data,
    output wire write_en, output wire [11:0] write_addr,
    output wire [7:0] write_data,
    output wire finished
);
    localparam IDLE=3'd0, REQUEST=3'd1, READ_WAIT=3'd2,
               CAPTURE=3'd3, STORE=3'd4, FINISH=3'd5;
    reg [2:0] state;
    reg [3:0] channel, y, x;
    reg [1:0] tap;
    reg [7:0] max_value;
    reg [7:0] candidate;

    // 2x2 input patch at (2*y,2*x).
    wire [4:0] source_y = {y,1'b0} + tap[1];
    wire [4:0] source_x = {x,1'b0} + tap[0];
    wire [13:0] source_offset = channel * 14'd784
                                 + source_y * 14'd28 + source_x;
    assign write_en = (state==STORE);
    assign write_addr = channel * 12'd196 + y * 12'd14 + x;
    assign write_data = max_value;
    assign finished = (state==FINISH);

    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; channel<=0; y<=0; x<=0; tap<=0;
            src_addr<=0; max_value<=0; candidate<=0;
        end else begin
            case(state)
                IDLE: if (start) begin
                    channel<=0; y<=0; x<=0; tap<=0; max_value<=0;
                    state<=REQUEST;
                end
                REQUEST: begin
                    src_addr <= source_offset;
                    state <= READ_WAIT;
                end
                // The source RAM samples src_addr at this rising edge.
                READ_WAIT: state<=CAPTURE;
                // The RAM output contains the requested sample at this edge.
                CAPTURE: begin
                    candidate <= src_data;
                    if (tap==0 || src_data>max_value) max_value<=src_data;
                    if (tap==3) state<=STORE;
                    else begin tap<=tap+1'b1; state<=REQUEST; end
                end
                STORE: begin
                    if (x==13) begin
                        x<=0;
                        if (y==13) begin
                            y<=0;
                            if (channel==15) state<=FINISH;
                            else begin channel<=channel+1'b1; tap<=0; max_value<=0; state<=REQUEST; end
                        end else begin y<=y+1'b1; tap<=0; max_value<=0; state<=REQUEST; end
                    end else begin x<=x+1'b1; tap<=0; max_value<=0; state<=REQUEST; end
                end
                FINISH: if(!start) state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
