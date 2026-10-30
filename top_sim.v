`timescale 1ns / 1ps
`include "../rtl/include.v"

`define MaxTestSamples 100

module top_sim();

    reg clock;
    reg resetn;

    reg [`dataWidth-1:0] in;
    reg in_valid;
    wire in_ready;

    wire intr;
    wire [31:0] nn_out;
    wire nn_out_valid;
    wire params_loaded_debug;

    reg [`dataWidth-1:0] in_mem [0:784];
    reg [7:0] fileName [23:0];
    reg [`dataWidth-1:0] expected;

    integer right = 0;
    integer testDataCount;
    integer testDataCount_int;
    integer i;

    zyNet dut(
        .s_axi_aclk(clock),
        .s_axi_aresetn(resetn),

        .axis_in_data(in),
        .axis_in_data_valid(in_valid),
        .axis_in_data_ready(in_ready),

        .s_axi_awaddr(5'd0),
        .s_axi_awprot(3'd0),
        .s_axi_awvalid(1'b0),
        .s_axi_awready(),

        .s_axi_wdata(32'd0),
        .s_axi_wstrb(4'h0),
        .s_axi_wvalid(1'b0),
        .s_axi_wready(),

        .s_axi_bresp(),
        .s_axi_bvalid(),
        .s_axi_bready(1'b0),

        .s_axi_araddr(5'd0),
        .s_axi_arprot(3'd0),
        .s_axi_arvalid(1'b0),
        .s_axi_arready(),

        .s_axi_rdata(),
        .s_axi_rresp(),
        .s_axi_rvalid(),
        .s_axi_rready(1'b0),

        .intr(intr),
        .nn_out(nn_out),
        .nn_out_valid(nn_out_valid),
        .params_loaded_debug(params_loaded_debug)
    );

    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock; // 100 MHz sim clock
    end

    function [7:0] to_ascii;
        input integer a;
        begin
            to_ascii = a + 48;
        end
    endfunction

    task makeTestFileName;
        input integer sample_num;
        integer temp;
        integer idx;
        begin
            temp = sample_num;

            fileName[0]  = "t";
            fileName[1]  = "x";
            fileName[2]  = "t";
            fileName[3]  = ".";
            fileName[4]  = "0";
            fileName[5]  = "0";
            fileName[6]  = "0";
            fileName[7]  = "0";

            idx = 0;
            while (temp != 0) begin
                fileName[idx+4] = to_ascii(temp % 10);
                temp = temp / 10;
                idx = idx + 1;
            end

            fileName[8]  = "_";
            fileName[9]  = "a";
            fileName[10] = "t";
            fileName[11] = "a";
            fileName[12] = "d";
            fileName[13] = "_";
            fileName[14] = "t";
            fileName[15] = "s";
            fileName[16] = "e";
            fileName[17] = "t";
        end
    endtask

    task sendData;
        integer t;
        begin
            $readmemb(fileName, in_mem);

            @(posedge clock);
            @(posedge clock);
            @(posedge clock);

            for (t = 0; t < 784; t = t + 1) begin
                @(posedge clock);
                in <= in_mem[t];
                in_valid <= 1'b1;
            end

            @(posedge clock);
            in_valid <= 1'b0;
            expected = in_mem[784];
        end
    endtask

    initial begin
        resetn = 1'b0;
        in = 0;
        in_valid = 1'b0;

        #200;
        resetn = 1'b1;

        $display("Waiting for param_loader...");
        wait(params_loaded_debug == 1'b1);
        $display("Parameter loading completed at %0t ns", $time);

        #100;

        for (testDataCount = 0; testDataCount < `MaxTestSamples; testDataCount = testDataCount + 1) begin

            makeTestFileName(testDataCount);

            sendData();

            wait(nn_out_valid == 1'b1);
            @(posedge clock);

            if (nn_out[`dataWidth-1:0] == expected)
                right = right + 1;

            $display("%0d. Accuracy: %f, Detected: %0x, Expected: %0x",
                     testDataCount + 1,
                     right * 100.0 / (testDataCount + 1),
                     nn_out[`dataWidth-1:0],
                     expected);

            #100;
        end

        $display("Final Accuracy: %f", right * 100.0 / `MaxTestSamples);
        $stop;
    end

endmodule