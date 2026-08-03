module fft_top (
    input logic clk,
    input logic reset,
    input logic start,
    input logic input_valid,
    output logic input_ready,
    input logic signed [fft_pkg::INPUT_W-1:0] input_real,
    input logic signed [fft_pkg::INPUT_W-1:0] input_imag,
    output logic busy,
    output logic done,
    output logic output_valid,
    input logic output_ready,
    output logic [fft_pkg::ADDR_W-1:0] output_bin,
    output logic signed [fft_pkg::SAMPLE_W-1:0] output_real,
    output logic signed [fft_pkg::SAMPLE_W-1:0] output_imag
);
    // TODO: integrate controller, memories, ROM, address generator, butterfly.
endmodule
