`timescale 1ns/1ps
module fft_address_gen #(
    parameter int ADDR_W = fft_pkg::ADDR_W
) (
    input  logic [2:0] stage,
    input  logic [4:0] butterfly_count,
    output logic [ADDR_W-1:0] addr_a,
    output logic [ADDR_W-1:0] addr_b,
    output logic [4:0] twiddle_addr
);
    
// Address generation for one radix-2 FFT butterfly.
//
// H = 2^stage
// Halfsize of the current butterfly group.
// It determines how far apart the two samples in a butterfly are.
// Stage 0: H=1, Stage 1: H=2, Stage 2: H=4, etc.
//
// group=  butterfly_count / H
// this Identifies which 2H sized block of samples this butterfly belongs to.
//
// j=butterfly_count % H
// Position of the butterfly inside the current group ranging from 0 to H-1.
//
// group_start=group * 2H
// First sample address of the current 2Hsized group.
//
// addr_a= group_start + j
// Address of the first sample in the butterfly pair.
//
// addr_b= addr_a + H
// Address of the second sample in the butterfly pair. It is always H locations after addr_a.
//
// twiddle_addr=j * 64 / (2H)
// Selects the twiddle factor W_64^k used by this butterfly.The twiddle pattern depends on j and the current stage.




always_comb begin

    addr_a = '0;
    addr_b = '0;
    twiddle_addr = '0;

    case (stage)

        3'd0: begin
            // H = 1
            addr_a = {butterfly_count, 1'b0};
            addr_b = addr_a + 6'd1;
            twiddle_addr = 5'd0;
        end

        3'd1: begin
            // H = 2
            addr_a = {butterfly_count[4:1], 2'b00}
                   + butterfly_count[0];
            addr_b = addr_a + 6'd2;

            twiddle_addr = butterfly_count[0] << 4;
        end

        3'd2: begin
            // H = 4
            addr_a = {butterfly_count[4:2], 3'b000}
                   + butterfly_count[1:0];
            addr_b = addr_a + 6'd4;

            twiddle_addr = butterfly_count[1:0] << 3;
        end

        3'd3: begin
            // H = 8
            addr_a = {butterfly_count[4:3], 4'b0000}
                   + butterfly_count[2:0];
            addr_b = addr_a + 6'd8;

            twiddle_addr = butterfly_count[2:0] << 2;
        end

        3'd4: begin
            // H = 16
            addr_a = {butterfly_count[4], 5'b00000}
                   + butterfly_count[3:0];
            addr_b = addr_a + 6'd16;

            twiddle_addr = butterfly_count[3:0] << 1;
        end

        3'd5: begin
            // H = 32
            addr_a = {1'b0, butterfly_count};
            addr_b = addr_a + 6'd32;

            twiddle_addr = butterfly_count;
        end

        default: begin
            addr_a = '0;
            addr_b = '0;
            twiddle_addr = '0;
        end

    endcase

end





endmodule

