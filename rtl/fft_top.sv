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
    logic [2:0] stage_count;
    logic [4:0] butterfly_count;

    logic [5:0] addr_a;
    logic [5:0] addr_b;
    logic [4:0] twiddle_addr;

    logic signed [fft_pkg::TWIDDLE_W-1:0] w_real;
    logic signed [fft_pkg::TWIDDLE_W-1:0] w_imag;

    fft_address_gen addr_gen (.stage(stage_count),
        .butterfly_count(butterfly_count),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .twiddle_addr(twiddle_addr)
    );

    twiddle_rom tw_rom (
        .clk(clk),
        .addr(twiddle_addr),

        .w_real(w_real),
        .w_imag(w_imag)
    );


endmodule
