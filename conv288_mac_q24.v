`timescale 1ns/1ps
// Sequential 288-term Conv3 MAC: 32 input channels x 3x3 taps.
// 288 signed 8-bit weights and 144 unsigned 8-bit activations, signed int32 bias.
// One term per clock when term_valid is asserted. The testbench supplies exactly
// 288 terms after start, with no idle-cycle restriction. First term may arrive
// on the cycle AFTER start; done pulses on acceptance of term #288.
// Matches integer_reference_original.py: conv_int + requant_relu with Q24
// round-to-nearest, ties away from zero, and clamp 0..255.
// This is the Conv3-specific MAC variant; the verified Conv1 MAC is unchanged.
module conv288_mac_q24 (
    input wire clk, input wire rst,
    input wire start,
    input wire signed [31:0] bias_q,
    input wire [31:0] multiplier_q24,
    input wire term_valid,
    input wire [7:0] activation_u8,
    input wire signed [7:0] weight_s8,
    output reg done,
    output reg [7:0] activation_out,
    output reg signed [31:0] accumulator_out,
    output reg overflow
);
    reg active;
    reg [8:0] term_count;
    reg signed [31:0] acc;
    reg [31:0] multiplier_reg;
    wire signed [16:0] product = $signed({1'b0,activation_u8}) * $signed(weight_s8);
    wire signed [33:0] sum_wide = $signed(acc) + $signed(product);
    wire signed [31:0] sum_sat = (sum_wide > 34'sd2147483647) ? 32'sh7fffffff :
        (sum_wide < -34'sd2147483648) ? 32'sh80000000 : sum_wide[31:0];
    wire sum_overflow = (sum_wide > 34'sd2147483647) || (sum_wide < -34'sd2147483648);
    wire signed [63:0] scaled = $signed(sum_sat) * $signed({1'b0,multiplier_reg});
    wire [63:0] magnitude = scaled[63] ? (~scaled + 64'd1) : scaled;
    wire [63:0] rounded_mag = (magnitude + 64'd8388608) >> 24;
    wire signed [63:0] rounded = scaled[63] ? -$signed(rounded_mag) : $signed(rounded_mag);
    wire [7:0] relu_sat = (rounded <= 0) ? 8'd0 : (rounded >= 255) ? 8'd255 : rounded[7:0];
    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0; term_count <= 0; acc <= 0;
            multiplier_reg <= 0; done <= 0; activation_out <= 0;
            accumulator_out <= 0; overflow <= 0;
        end else begin
            done <= 0;
            if (start) begin
                active <= 1'b1; term_count <= 0; acc <= bias_q;
                multiplier_reg <= multiplier_q24; overflow <= 0;
            end else if (active && term_valid) begin
                acc <= sum_sat;
                overflow <= overflow | sum_overflow;
                term_count <= term_count + 1'b1;
                if (term_count == 9'd287) begin
                    active <= 1'b0;
                    accumulator_out <= sum_sat;
                    activation_out <= relu_sat;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule
