`timescale 1ns/1ps

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
   

        (* ram_style = "block" *)
        logic [2*SAMPLE_W-1:0] mem [0:DEPTH-1];

       

        always_ff @(posedge clk) begin
            port_a_rreal <= mem[port_a_addr][2*SAMPLE_W-1:SAMPLE_W];
            port_a_rimag <= mem[port_a_addr][SAMPLE_W-1:0];

            if (port_a_we) begin
                mem[port_a_addr] <= {port_a_wreal, port_a_wimag};
            end
        end

        always_ff @(posedge clk) begin
            port_b_rreal <= mem[port_b_addr][2*SAMPLE_W-1:SAMPLE_W];
            port_b_rimag <= mem[port_b_addr][SAMPLE_W-1:0];

            if (port_b_we) begin
                mem[port_b_addr] <= {port_b_wreal, port_b_wimag};
            end
        end


endmodule

