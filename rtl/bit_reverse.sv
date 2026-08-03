module bit_reverse #(
    parameter int WIDTH = fft_pkg::ADDR_W
) (
    input  logic [WIDTH-1:0] index_in,
    output logic [WIDTH-1:0] index_out
);
    // TODO: combinational bit reversal.
endmodule
