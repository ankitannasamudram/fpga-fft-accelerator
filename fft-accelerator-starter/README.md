# 64-Point Fixed-Point FFT Accelerator

Starter repository for a 64-point radix-2 fixed-point FFT accelerator in SystemVerilog.

## Architecture
- 64 complex samples
- 6 radix-2 stages
- 32 butterflies per stage
- one reusable pipelined butterfly
- two ping-pong sample memories
- bit-reversed input loading
- registered twiddle ROM
- SystemVerilog + cocotb verification
- Python bit-accurate model and NumPy comparison

## Implementation order
1. complex_mult
2. fft_butterfly
3. twiddle_rom
4. bit_reverse
5. fft_address_gen
6. fft_memory
7. fft_controller
8. fft_top
