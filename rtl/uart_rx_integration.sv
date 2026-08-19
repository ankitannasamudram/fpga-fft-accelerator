`timescale 1ns/1ps

module uart_rx_integration (
    input  logic clk,
    input  logic reset,
    input  logic uart_rx,

    output logic signed [15:0] sample_real,
    output logic signed [15:0] sample_imag,
    output logic               sample_valid
);

    // Byte level connection between UART RX and sample assembler
    logic [7:0] rx_data;
    logic       rx_valid;


    
    // UART receiver
    //
    // Converts: 
    // serial uart_rx waveform
    // into
    // rx_data[7:0]
    // rx_valid
    

    uart_rx uart_receiver (
        .clk      (clk),
        .reset    (reset),
        .uart_rx  (uart_rx),

        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );


    
    // Sample assembler
    //
    // Converts every four received UART bytes:
    // byte 0 = real low
    // byte 1 = real high
    // byte 2 = imag low
    // byte 3 = imag high
    // into:
    
    // sample_real[15:0]
    // sample_imag[15:0]
    // sample_valid
    

    uart_sample_assembler assembler (
        .clk          (clk),
        .reset        (reset),

        .rx_data      (rx_data),
        .rx_valid     (rx_valid),

        .sample_real  (sample_real),
        .sample_imag  (sample_imag),
        .sample_valid (sample_valid)
    );

endmodule