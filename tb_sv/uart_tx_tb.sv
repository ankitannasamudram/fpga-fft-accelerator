`timescale 1ns/1ps

module uart_tx_tb;

    localparam int CLK_FREQ = 100_000_000;
    localparam int BAUD_RATE = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    logic clk;
    logic reset;

    logic [7:0] tx_data;
    logic tx_valid;

    logic uart_tx;
    logic tx_busy;


    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .reset(reset),

        .tx_data(tx_data),
        .tx_valid(tx_valid),

        .uart_tx(uart_tx),
        .tx_busy(tx_busy)
    );


    // 100 MHz FPGA clock
    initial clk = 0;
    always #5 clk = ~clk;


    // request transmission of one byte
    task send_byte(input logic [7:0] data);
        begin

            // only request a transmission when the transmitter is free
            while (tx_busy)
                @(posedge clk);

            @(negedge clk);

            tx_data = data;
            tx_valid = 1'b1;

            // tx_valid only needs to be high for one clock
            @(negedge clk);

            tx_valid = 1'b0;

        end
    endtask


    // receive the serial byte produced by uart_tx
    // this acts like a UART receiver in the testbench
    task check_byte(input logic [7:0] expected);
        integer i;
        logic [7:0] received;

        begin

            received = 8'h00;

            // wait for the start bit
            @(negedge uart_tx);

            // move to the middle of the start bit
            repeat(CLKS_PER_BIT / 2)
                @(posedge clk);

            if (uart_tx !== 1'b0) begin
                $display("FAIL: invalid start bit");
                $finish;
            end

            // move one full bit time to the middle of data bit 0
            repeat(CLKS_PER_BIT)
                @(posedge clk);

            // sample all 8 data bits
            for (i = 0; i < 8; i = i + 1) begin

                received[i] = uart_tx;

                repeat(CLKS_PER_BIT)
                    @(posedge clk);

            end

            // we should now be in the middle of the stop bit
            if (uart_tx !== 1'b1) begin
                $display("FAIL: invalid stop bit");
                $finish;
            end

            if (received !== expected) begin
                $display(
                    "FAIL: expected %h, received %h",
                    expected,
                    received
                );
                $finish;
            end

            else begin
                $display(
                    "PASS: transmitted %h correctly",
                    received
                );
            end

        end
    endtask


    initial begin

        reset = 1'b1;
        tx_data = 8'h00;
        tx_valid = 1'b0;

        repeat(5)
            @(posedge clk);

        @(negedge clk);
        reset = 1'b0;


        // test first byte
        fork

            send_byte(8'h53);
            check_byte(8'h53);

        join


        // test another byte
        fork

            send_byte(8'hA5);
            check_byte(8'hA5);

        join


        // test all zeros
        fork

            send_byte(8'h00);
            check_byte(8'h00);

        join


        // test all ones
        fork

            send_byte(8'hFF);
            check_byte(8'hFF);

        join


        $display("PASS: all UART TX tests completed");

        $finish;

    end

endmodule