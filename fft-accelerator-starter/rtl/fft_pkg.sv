package fft_pkg;
    parameter int FFT_N             = 64;
    parameter int ADDR_W            = 6;
    parameter int NUM_STAGES        = 6;
    parameter int BUTTERFLIES_STAGE = 32;
    parameter int INPUT_W           = 16;
    parameter int SAMPLE_W          = 22;
    parameter int TWIDDLE_W         = 16;
    parameter int FRAC_W            = 15;

    typedef struct packed {
        logic [ADDR_W-1:0] addr_a;
        logic [ADDR_W-1:0] addr_b;
        logic              valid;
        logic              last;
    } fft_metadata_t;
endpackage
