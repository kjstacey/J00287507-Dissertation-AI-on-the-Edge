`timescale 1ns / 1ps
`include "include.v"

module param_loader (
    input  wire        clk,
    input  wire        rst,

    output reg  [31:0] layerNumber,
    output reg  [31:0] neuronNumber,

    output reg  [31:0] weightValue,
    output reg         weightValid,

    output reg  [31:0] biasValue,
    output reg         biasValid,

    output reg         done,
    output wire loading_debug
);

    // Network structure:
    // L1: 30 neurons, 784 weights each, 30 biases
    // L2: 20 neurons, 30 weights each, 20 biases
    // L3: 10 neurons, 20 weights each, 10 biases

    localparam integer L1_NEURONS = 30;
    localparam integer L1_WEIGHTS = 784;
    localparam integer L2_NEURONS = 20;
    localparam integer L2_WEIGHTS = 30;
    localparam integer L3_NEURONS = 10;
    localparam integer L3_WEIGHTS = 20;

    localparam integer TOTAL_WEIGHTS =
        (L1_NEURONS * L1_WEIGHTS) +
        (L2_NEURONS * L2_WEIGHTS) +
        (L3_NEURONS * L3_WEIGHTS);

    localparam integer TOTAL_BIASES =
        L1_NEURONS + L2_NEURONS + L3_NEURONS;

    reg [31:0] weight_rom [0:TOTAL_WEIGHTS-1];
    reg [31:0] bias_rom   [0:TOTAL_BIASES-1];

    initial begin
        $readmemh("weights.mem", weight_rom);
        $readmemh("biases.mem", bias_rom);
    end

    localparam S_WEIGHTS = 2'd0;
    localparam S_BIASES  = 2'd1;
    localparam S_DONE    = 2'd2;

    reg [1:0] state = S_WEIGHTS;

    integer layer;
    integer neuron;
    integer weight_index;
    integer global_weight_index;
    integer global_bias_index;
    assign loading_debug = ~done;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_WEIGHTS;

            layer <= 1;
            neuron <= 0;
            weight_index <= 0;
            global_weight_index <= 0;
            global_bias_index <= 0;

            layerNumber <= 0;
            neuronNumber <= 0;

            weightValue <= 0;
            biasValue <= 0;

            weightValid <= 1'b0;
            biasValid <= 1'b0;
            done <= 1'b0;
        end else begin
            weightValid <= 1'b0;
            biasValid <= 1'b0;

            case (state)

                S_WEIGHTS: begin
                    layerNumber  <= layer;
                    neuronNumber <= neuron;
                    weightValue  <= weight_rom[global_weight_index];
                    weightValid  <= 1'b1;

                    global_weight_index <= global_weight_index + 1;

                    if ((layer == 1 && weight_index == L1_WEIGHTS-1) ||
                        (layer == 2 && weight_index == L2_WEIGHTS-1) ||
                        (layer == 3 && weight_index == L3_WEIGHTS-1)) begin

                        weight_index <= 0;

                        if ((layer == 1 && neuron == L1_NEURONS-1) ||
                            (layer == 2 && neuron == L2_NEURONS-1) ||
                            (layer == 3 && neuron == L3_NEURONS-1)) begin

                            neuron <= 0;

                            if (layer == 3) begin
                                layer <= 1;
                                state <= S_BIASES;
                            end else begin
                                layer <= layer + 1;
                            end

                        end else begin
                            neuron <= neuron + 1;
                        end

                    end else begin
                        weight_index <= weight_index + 1;
                    end
                end

                S_BIASES: begin
                    layerNumber  <= layer;
                    neuronNumber <= neuron;
                    biasValue    <= bias_rom[global_bias_index];
                    biasValid    <= 1'b1;

                    global_bias_index <= global_bias_index + 1;

                    if ((layer == 1 && neuron == L1_NEURONS-1) ||
                        (layer == 2 && neuron == L2_NEURONS-1) ||
                        (layer == 3 && neuron == L3_NEURONS-1)) begin

                        neuron <= 0;

                        if (layer == 3) begin
                            state <= S_DONE;
                            done <= 1'b1;
                        end else begin
                            layer <= layer + 1;
                        end

                    end else begin
                        neuron <= neuron + 1;
                    end
                end

                S_DONE: begin
                    weightValid <= 1'b0;
                    biasValid <= 1'b0;
                    done <= 1'b1;
                end

                default: begin
                    state <= S_DONE;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule