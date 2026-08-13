module twiddle_rom #(
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W
) (
    input  logic clk,
    input  logic [4:0] addr,
    output logic signed [TWIDDLE_W-1:0] w_real,
    output logic signed [TWIDDLE_W-1:0] w_imag
);
    
logic signed [TWIDDLE_W-1:0] twiddle_real [0:31];
logic signed [TWIDDLE_W-1:0] twiddle_imag [0:31];

// The FFT twiddle factor is:
//
//     W_N^k = exp(-j*2*pi*k/N)
//
// Using Euler's formula:
//
//     W_N^k = cos(2*pi*k/N) - j*sin(2*pi*k/N)
//
// For this design N = 64, so each ROM address k stores:
//
//     w_real = cos(2*pi*k/64)
//     w_imag = -sin(2*pi*k/64)
//
// The sine and cosine values are precomputed instead of calculated in hardware. They are
// stored in signed Q1.15 fixed point format where 16 total bits with 15 fractional bits
//
// so the formula essentially is 
// w_real = cos(2*pi*k/64) * 2^15
// w_imag = -sin(2*pi*k/64) * 2^15

initial begin
    twiddle_real[0]  =  32767; twiddle_imag[0]  =      0;
    twiddle_real[1]  =  32610; twiddle_imag[1]  =  -3212;
    twiddle_real[2]  =  32138; twiddle_imag[2]  =  -6393;
    twiddle_real[3]  =  31357; twiddle_imag[3]  =  -9512;
    twiddle_real[4]  =  30274; twiddle_imag[4]  = -12540;
    twiddle_real[5]  =  28899; twiddle_imag[5]  = -15447;
    twiddle_real[6]  =  27246; twiddle_imag[6]  = -18205;
    twiddle_real[7]  =  25330; twiddle_imag[7]  = -20788;
    twiddle_real[8]  =  23170; twiddle_imag[8]  = -23170;
    twiddle_real[9]  =  20788; twiddle_imag[9]  = -25330;
    twiddle_real[10] =  18205; twiddle_imag[10] = -27246;
    twiddle_real[11] =  15447; twiddle_imag[11] = -28899;
    twiddle_real[12] =  12540; twiddle_imag[12] = -30274;
    twiddle_real[13] =   9512; twiddle_imag[13] = -31357;
    twiddle_real[14] =   6393; twiddle_imag[14] = -32138;
    twiddle_real[15] =   3212; twiddle_imag[15] = -32610;

    twiddle_real[16] =      0; twiddle_imag[16] = -32768;
    twiddle_real[17] =  -3212; twiddle_imag[17] = -32610;
    twiddle_real[18] =  -6393; twiddle_imag[18] = -32138;
    twiddle_real[19] =  -9512; twiddle_imag[19] = -31357;
    twiddle_real[20] = -12540; twiddle_imag[20] = -30274;
    twiddle_real[21] = -15447; twiddle_imag[21] = -28899;
    twiddle_real[22] = -18205; twiddle_imag[22] = -27246;
    twiddle_real[23] = -20788; twiddle_imag[23] = -25330;
    twiddle_real[24] = -23170; twiddle_imag[24] = -23170;
    twiddle_real[25] = -25330; twiddle_imag[25] = -20788;
    twiddle_real[26] = -27246; twiddle_imag[26] = -18205;
    twiddle_real[27] = -28899; twiddle_imag[27] = -15447;
    twiddle_real[28] = -30274; twiddle_imag[28] = -12540;
    twiddle_real[29] = -31357; twiddle_imag[29] =  -9512;
    twiddle_real[30] = -32138; twiddle_imag[30] =  -6393;
    twiddle_real[31] = -32610; twiddle_imag[31] =  -3212;
end


// The address is presented during the current cycle and the
// corresponding real and imaginary twiddle values appear after the next rising clock edge.
// This gives the twiddle ROM a 1 cycle latency matching the
// 1cycle synchronous sample-memory read latency.
    always_ff (@posedge clk) begin
        w_real <= twiddle_real[addr];
        w_imag <= twiddle_imag[addr];
    end

endmodule
