`timescale 1ns/1ps

module fft_board_top (
    input  logic clk,
    input  logic btn_start,
    input  logic btn_reset,

    input  logic uart_rx,
    output logic uart_tx,

    output logic led_start,
    output logic led_busy,
    output logic led_done
);


    // Synchronize reset button

    logic reset_ff1;
    logic reset_ff2;
    logic core_reset;

    always_ff @(posedge clk or posedge btn_reset) begin
        if (btn_reset) begin
            reset_ff1 <= 1'b1;
            reset_ff2 <= 1'b1;
        end
        else begin
            reset_ff1 <= 1'b0;
            reset_ff2 <= reset_ff1;
        end
    end

    assign core_reset = reset_ff2;


    // Synchronize start button + make one-cycle pulse

    logic start_ff1;
    logic start_ff2;
    logic start_ff2_d;

    logic start_pulse;

    always_ff @(posedge clk) begin
        if (core_reset) begin
            start_ff1   <= 1'b0;
            start_ff2   <= 1'b0;
            start_ff2_d <= 1'b0;
        end
        else begin
            start_ff1   <= btn_start;
            start_ff2   <= start_ff1;
            start_ff2_d <= start_ff2;
        end
    end

    assign start_pulse = start_ff2 & ~start_ff2_d;


    // UART + FFT system signals

    logic core_busy;
    logic core_done;

    logic signed [21:0] fft_output_real;
    logic signed [21:0] fft_output_imag;
    logic               fft_output_valid;


    // Full UART + FFT system
    //
    // PC UART data enters through uart_rx.
    // The samples are assembled and fed into the FFT.
    // The FFT results are serialized and sent back through uart_tx.

    uart_fft_top fft_system (
        .clk              (clk),
        .reset            (core_reset),
        .start            (start_pulse),

        .uart_rx          (uart_rx),
        .uart_tx          (uart_tx),

        .busy             (core_busy),
        .done             (core_done),

        .fft_output_real  (fft_output_real),
        .fft_output_imag  (fft_output_imag),
        .fft_output_valid (fft_output_valid)
    );


    // LED indicators

    // Turns on when a synchronized start pulse occurs.
    // Stays on until reset.
    always_ff @(posedge clk) begin
        if (core_reset)
            led_start <= 1'b0;
        else if (start_pulse)
            led_start <= 1'b1;
    end


    // Busy directly reflects the FFT system.
    assign led_busy = core_busy;


    // Done is only one clock inside the FFT system,
    // so latch it so you can actually see it on an LED.
    always_ff @(posedge clk) begin
        if (core_reset)
            led_done <= 1'b0;
        else if (start_pulse)
            led_done <= 1'b0;
        else if (core_done)
            led_done <= 1'b1;
    end


endmodule