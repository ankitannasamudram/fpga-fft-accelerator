module fft_memory #(
    parameter int DEPTH    = fft_pkg::FFT_N,
    parameter int SAMPLE_W = fft_pkg::SAMPLE_W,
    parameter int ADDR_W   = fft_pkg::ADDR_W
) (
    input logic clk,
    input logic port_a_we,
    input logic [ADDR_W-1:0] port_a_addr,
    input logic signed [SAMPLE_W-1:0] port_a_wreal,
    input logic signed [SAMPLE_W-1:0] port_a_wimag,
    output logic signed [SAMPLE_W-1:0] port_a_rreal,
    output logic signed [SAMPLE_W-1:0] port_a_rimag,
    input logic port_b_we,
    input logic [ADDR_W-1:0] port_b_addr,
    input logic signed [SAMPLE_W-1:0] port_b_wreal,
    input logic signed [SAMPLE_W-1:0] port_b_wimag,
    output logic signed [SAMPLE_W-1:0] port_b_rreal,
    output logic signed [SAMPLE_W-1:0] port_b_rimag
);
    // TODO: dual-port, one-cycle-read complex sample memory.
endmodule
