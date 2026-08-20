`timescale 1ns/1ps

module uart_fft_top #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic uart_rx,

    output logic busy,
    output logic done,

    output logic signed [21:0] fft_output_real,
    output logic signed [21:0] fft_output_imag,
    output logic               fft_output_valid
);

    
    // UART RX -> SAMPLE ASSEMBLER
    

    logic [7:0] rx_data;
    logic       rx_valid;

    logic signed [15:0] sample_real;
    logic signed [15:0] sample_imag;
    logic               sample_valid;


    
    // FFT handshake signals
    

    logic fft_input_ready;
    logic fft_output_ready;


    // For now we are ALWAYS ready to accept FFT outputs.
    // Later uart_tx will control this.
    assign fft_output_ready = 1'b1;


    
    // UART RECEIVER
    //
    // Serial bits:
    //
    // uart_rx to 
    // rx_data + rx_valid
    

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_receiver (
        .clk      (clk),
        .reset    (reset),
        .uart_rx  (uart_rx),

        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );


    
    // UART SAMPLE ASSEMBLER
    //
    // Four UART bytes:
    //
    // real low
    // real high
    // imag low
    // imag high
    //
    // become one complex 16-bit sample.
    

    uart_sample_assembler sample_assembler (
        .clk          (clk),
        .reset        (reset),

        .rx_data      (rx_data),
        .rx_valid     (rx_valid),

        .sample_real  (sample_real),
        .sample_imag  (sample_imag),
        .sample_valid (sample_valid)
    );


    
    // FFT CORE
    //
    // Press START:
    //
    // IDLE -> LOAD
    //
    // During LOAD:
    // input_ready = 1
    //
    // Every sample_valid pulse from the assembler therefore
    // becomes one FFT input sample.
    

    fft_top fft_core (
        .clk          (clk),
        .reset        (reset),
        .start        (start),

        .input_valid  (sample_valid),
        .input_ready  (fft_input_ready),

        .input_real   (sample_real),
        .input_imag   (sample_imag),

        .output_valid (fft_output_valid),
        .output_ready (fft_output_ready),

        .output_real  (fft_output_real),
        .output_imag  (fft_output_imag),

        .busy         (busy),
        .done         (done)
    );

endmodule