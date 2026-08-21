`timescale 1ns/1ps

module uart_fft_serializer_tb;

    logic clk;
    logic reset;

    logic signed [21:0] fft_real;
    logic signed [21:0] fft_imag;
    logic               fft_valid;
    logic               fft_ready;

    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_busy;


    uart_fft_serializer dut (
        .clk       (clk),
        .reset     (reset),

        .fft_real  (fft_real),
        .fft_imag  (fft_imag),
        .fft_valid (fft_valid),
        .fft_ready (fft_ready),

        .tx_data   (tx_data),
        .tx_valid  (tx_valid),
        .tx_busy   (tx_busy)
    );


    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;


    // this task gives one FFT bin to the serializer
    task send_fft_bin(
        input logic signed [21:0] real_value,
        input logic signed [21:0] imag_value
    );
        begin

            // wait until the serializer is ready for a new FFT bin
            while (!fft_ready)
                @(posedge clk);

            @(negedge clk);

            fft_real = real_value;
            fft_imag = imag_value;
            fft_valid = 1'b1;

            // fft_valid only needs to be high for one clock
            @(negedge clk);

            fft_valid = 1'b0;

        end
    endtask


    // this task acts like uart_tx
    // every time tx_valid pulses, it captures the byte
    // then it raises tx_busy to show that the byte was accepted
    task check_byte(input logic [7:0] expected);
        begin

            // wait until the serializer presents a byte
            while (!tx_valid)
                @(posedge clk);

            if (tx_data !== expected) begin
                $display(
                    "FAIL: expected byte %h, got %h",
                    expected,
                    tx_data
                );

                $finish;
            end

            $display(
                "PASS: byte %h",
                tx_data
            );

            // pretend uart_tx accepted the byte and became busy
            @(negedge clk);
            tx_busy = 1'b1;

            @(negedge clk);
            tx_busy = 1'b0;

        end
    endtask


    initial begin

        reset = 1'b1;

        fft_real = '0;
        fft_imag = '0;
        fft_valid = 1'b0;

        tx_busy = 1'b0;

        repeat(5)
            @(posedge clk);

        @(negedge clk);
        reset = 1'b0;


        // test a positive real and positive imaginary value
        fork

            send_fft_bin(
                22'sh12345,
                22'sh23456
            );

            begin

                check_byte(8'h45);
                check_byte(8'h23);
                check_byte(8'h01);

                check_byte(8'h56);
                check_byte(8'h34);
                check_byte(8'h02);

            end

        join


        // test negative values to make sure sign extension works
        fork

            send_fft_bin(
                -22'sd1,
                -22'sd2
            );

            begin

                check_byte(8'hFF);
                check_byte(8'hFF);
                check_byte(8'hFF);

                check_byte(8'hFE);
                check_byte(8'hFF);
                check_byte(8'hFF);

            end

        join


        $display("PASS: UART FFT serializer test completed");

        $finish;

    end

endmodule