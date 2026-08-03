module twiddle_rom #(
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W
) (
    input  logic clk,
    input  logic [4:0] addr,
    output logic signed [TWIDDLE_W-1:0] w_real,
    output logic signed [TWIDDLE_W-1:0] w_imag
);
    // TODO: 32 registered W_64^k entries.
endmodule
