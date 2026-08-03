module fft_butterfly #(
    parameter int SAMPLE_W  = fft_pkg::SAMPLE_W,
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W,
    parameter int FRAC_W    = fft_pkg::FRAC_W
) (
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic signed [SAMPLE_W-1:0]  a_real,
    input  logic signed [SAMPLE_W-1:0]  a_imag,
    input  logic signed [SAMPLE_W-1:0]  b_real,
    input  logic signed [SAMPLE_W-1:0]  b_imag,
    input  logic signed [TWIDDLE_W-1:0] w_real,
    input  logic signed [TWIDDLE_W-1:0] w_imag,
    output logic valid_out,
    output logic signed [SAMPLE_W-1:0] y0_real,
    output logic signed [SAMPLE_W-1:0] y0_imag,
    output logic signed [SAMPLE_W-1:0] y1_real,
    output logic signed [SAMPLE_W-1:0] y1_imag
);
    // TODO: instantiate complex_mult, delay A, compute A +/- T.
endmodule
