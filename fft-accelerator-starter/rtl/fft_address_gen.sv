module fft_address_gen #(
    parameter int ADDR_W = fft_pkg::ADDR_W
) (
    input  logic [2:0] stage,
    input  logic [4:0] butterfly_count,
    output logic [ADDR_W-1:0] addr_a,
    output logic [ADDR_W-1:0] addr_b,
    output logic [4:0] twiddle_addr
);
    // TODO: generate sample and twiddle addresses.
endmodule
