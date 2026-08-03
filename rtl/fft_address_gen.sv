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




logic [ADDR_W-1:0] H;
logic [ADDR_W-1:0] group;
logic [ADDR_W-1:0] j;
logic [ADDR_W-1:0] group_start;

    always_comb begin
        H = 1 << stage;
        group = butterfly_count/H;
        j = butterfly_count%H;
        group_start = group*2*H;

        addr_a = group_start +j;
        addr_b = addr_a+H;
        twiddle_addr = j*fft_pkg::FFT_N/(2*H);
    end





endmodule
