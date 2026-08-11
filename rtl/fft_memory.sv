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
   

    logic signed [SAMPLE_W-1:0] mem_real [0:DEPTH-1];
    logic signed [SAMPLE_W-1:0] mem_imag [0:DEPTH-1];

    always_ff @( posedge clk ) begin 
        port_a_rreal <= mem_real[port_a_addr];
        port_a_rimag <= mem_imag[port_a_addr];

        port_b_rreal <= mem_real[port_b_addr];
        port_b_rimag <= mem_imag[port_b_addr];

        if (port_a_we == 1) begin
            mem_real[port_a_addr]<= port_a_wreal;
            mem_imag[port_a_addr]<= port_a_wimag;
        end
        if (port_b_we ==1) begin
            mem_real[port_b_addr]<= port_b_wreal;
            mem_imag[port_b_addr]<= port_b_wimag;
        end



        
    end


endmodule

