`timescale 1ns / 1ps
`include "include.v"

module zyNet #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5
)
(
    input                                   s_axi_aclk,
    input                                   s_axi_aresetn,

    input [`dataWidth-1:0]                  axis_in_data,
    input                                   axis_in_data_valid,
    output                                  axis_in_data_ready,

    input wire [C_S_AXI_ADDR_WIDTH-1 : 0]   s_axi_awaddr,
    input wire [2 : 0]                      s_axi_awprot,
    input wire                              s_axi_awvalid,
    output wire                             s_axi_awready,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0]   s_axi_wdata,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input wire                              s_axi_wvalid,
    output wire                             s_axi_wready,
    output wire [1 : 0]                     s_axi_bresp,
    output wire                             s_axi_bvalid,
    input wire                              s_axi_bready,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0]   s_axi_araddr,
    input wire [2 : 0]                      s_axi_arprot,
    input wire                              s_axi_arvalid,
    output wire                             s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0]  s_axi_rdata,
    output wire [1 : 0]                     s_axi_rresp,
    output wire                             s_axi_rvalid,
    input wire                              s_axi_rready,

    output wire                             intr,
    output wire [31:0]                      nn_out,
    output wire                             nn_out_valid,
    output wire                             params_loaded_debug
);

wire [31:0] config_layer_num;
wire [31:0] config_neuron_num;
wire [31:0] weightValue;
wire [31:0] biasValue;
wire [31:0] out;
wire out_valid;
wire weightValid;
wire biasValid;
wire params_loaded;
wire safe_axis_valid;

assign s_axi_awready = 1'b0;
assign s_axi_wready  = 1'b0;
assign s_axi_bresp   = 2'b00;
assign s_axi_bvalid  = 1'b0;
assign s_axi_arready = 1'b0;
assign s_axi_rdata   = 32'd0;
assign s_axi_rresp   = 2'b00;
assign s_axi_rvalid  = 1'b0;

assign intr = out_valid;
assign axis_in_data_ready = 1'b1;
assign nn_out = out;
assign nn_out_valid = out_valid;
assign params_loaded_debug = params_loaded;

reg [7:0] rst_count = 8'd0;

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn)
        rst_count <= 8'd0;
    else if (rst_count != 8'hFF)
        rst_count <= rst_count + 1'b1;
end

wire reset;
assign reset = (rst_count != 8'hFF);

assign safe_axis_valid = axis_in_data_valid & params_loaded & ~reset;

param_loader loader (
    .clk(s_axi_aclk),
    .rst(reset),
    .layerNumber(config_layer_num),
    .neuronNumber(config_neuron_num),
    .weightValue(weightValue),
    .weightValid(weightValid),
    .biasValue(biasValue),
    .biasValid(biasValid),
    .done(params_loaded)
);

localparam IDLE = 'd0,
           SEND = 'd1;

wire [`numNeuronLayer1-1:0] o1_valid;
wire [`numNeuronLayer1*`dataWidth-1:0] x1_out;
reg [`numNeuronLayer1*`dataWidth-1:0] holdData_1;
reg [`dataWidth-1:0] out_data_1;
reg data_out_valid_1;

Layer_1 #(
    .NN(`numNeuronLayer1),
    .numWeight(`numWeightLayer1),
    .dataWidth(`dataWidth),
    .layerNum(1),
    .sigmoidSize(`sigmoidSize),
    .weightIntWidth(`weightIntWidth),
    .actType(`Layer1ActType)
) l1 (
    .clk(s_axi_aclk),
    .rst(reset),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .weightValue(weightValue),
    .biasValue(biasValue),
    .config_layer_num(config_layer_num),
    .config_neuron_num(config_neuron_num),
    .x_valid(safe_axis_valid),
    .x_in(axis_in_data),
    .o_valid(o1_valid),
    .x_out(x1_out)
);

reg state_1;
integer count_1;

always @(posedge s_axi_aclk) begin
    if (reset) begin
        state_1 <= IDLE;
        count_1 <= 0;
        data_out_valid_1 <= 0;
    end else begin
        case (state_1)
            IDLE: begin
                count_1 <= 0;
                data_out_valid_1 <= 0;
                if (o1_valid[0] == 1'b1) begin
                    holdData_1 <= x1_out;
                    state_1 <= SEND;
                end
            end

            SEND: begin
                out_data_1 <= holdData_1[`dataWidth-1:0];
                holdData_1 <= holdData_1 >> `dataWidth;
                count_1 <= count_1 + 1;
                data_out_valid_1 <= 1;

                if (count_1 == `numNeuronLayer1) begin
                    state_1 <= IDLE;
                    data_out_valid_1 <= 0;
                end
            end
        endcase
    end
end

wire [`numNeuronLayer2-1:0] o2_valid;
wire [`numNeuronLayer2*`dataWidth-1:0] x2_out;
reg [`numNeuronLayer2*`dataWidth-1:0] holdData_2;
reg [`dataWidth-1:0] out_data_2;
reg data_out_valid_2;

Layer_2 #(
    .NN(`numNeuronLayer2),
    .numWeight(`numWeightLayer2),
    .dataWidth(`dataWidth),
    .layerNum(2),
    .sigmoidSize(`sigmoidSize),
    .weightIntWidth(`weightIntWidth),
    .actType(`Layer2ActType)
) l2 (
    .clk(s_axi_aclk),
    .rst(reset),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .weightValue(weightValue),
    .biasValue(biasValue),
    .config_layer_num(config_layer_num),
    .config_neuron_num(config_neuron_num),
    .x_valid(data_out_valid_1),
    .x_in(out_data_1),
    .o_valid(o2_valid),
    .x_out(x2_out)
);

reg state_2;
integer count_2;

always @(posedge s_axi_aclk) begin
    if (reset) begin
        state_2 <= IDLE;
        count_2 <= 0;
        data_out_valid_2 <= 0;
    end else begin
        case (state_2)
            IDLE: begin
                count_2 <= 0;
                data_out_valid_2 <= 0;
                if (o2_valid[0] == 1'b1) begin
                    holdData_2 <= x2_out;
                    state_2 <= SEND;
                end
            end

            SEND: begin
                out_data_2 <= holdData_2[`dataWidth-1:0];
                holdData_2 <= holdData_2 >> `dataWidth;
                count_2 <= count_2 + 1;
                data_out_valid_2 <= 1;

                if (count_2 == `numNeuronLayer2) begin
                    state_2 <= IDLE;
                    data_out_valid_2 <= 0;
                end
            end
        endcase
    end
end

wire [`numNeuronLayer3-1:0] o3_valid;
wire [`numNeuronLayer3*`dataWidth-1:0] x3_out;
reg [`numNeuronLayer3*`dataWidth-1:0] holdData_3;
reg [`dataWidth-1:0] out_data_3;
reg data_out_valid_3;

Layer_3 #(
    .NN(`numNeuronLayer3),
    .numWeight(`numWeightLayer3),
    .dataWidth(`dataWidth),
    .layerNum(3),
    .sigmoidSize(`sigmoidSize),
    .weightIntWidth(`weightIntWidth),
    .actType(`Layer3ActType)
) l3 (
    .clk(s_axi_aclk),
    .rst(reset),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .weightValue(weightValue),
    .biasValue(biasValue),
    .config_layer_num(config_layer_num),
    .config_neuron_num(config_neuron_num),
    .x_valid(data_out_valid_2),
    .x_in(out_data_2),
    .o_valid(o3_valid),
    .x_out(x3_out)
);

reg state_3;
integer count_3;

always @(posedge s_axi_aclk) begin
    if (reset) begin
        state_3 <= IDLE;
        count_3 <= 0;
        data_out_valid_3 <= 0;
    end else begin
        case (state_3)
            IDLE: begin
                count_3 <= 0;
                data_out_valid_3 <= 0;
                if (o3_valid[0] == 1'b1) begin
                    holdData_3 <= x3_out;
                    state_3 <= SEND;
                end
            end

            SEND: begin
                out_data_3 <= holdData_3[`dataWidth-1:0];
                holdData_3 <= holdData_3 >> `dataWidth;
                count_3 <= count_3 + 1;
                data_out_valid_3 <= 1;

                if (count_3 == `numNeuronLayer3) begin
                    state_3 <= IDLE;
                    data_out_valid_3 <= 0;
                end
            end
        endcase
    end
end

maxFinder #(
    .numInput(`numNeuronLayer3),
    .inputWidth(`dataWidth)
) mFind (
    .i_clk(s_axi_aclk),
    .i_data(x3_out),
    .i_valid(o3_valid),
    .o_data(out),
    .o_data_valid(out_valid)
);

endmodule