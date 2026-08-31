# 64-Point Fixed-Point FPGA FFT Accelerator

A 64-point radix-2 FFT accelerator written in SystemVerilog and implemented on a
Digilent Nexys A7-100T.

The design uses one reused pipelined butterfly, ping-pong sample memory, a twiddle
ROM, custom address/control logic, and a full UART path to a Python host.

**End-to-end path**

`Python host -> USB-UART -> FPGA FFT -> USB-UART -> Python/NumPy comparison`

The full system was tested on hardware and returned all 64 FFT bins correctly.

---

## Project Highlights

- 64-point radix-2 FFT
- 6 stages, 32 butterflies per stage
- One reused 5-cycle butterfly
- Butterfly initiation interval: **II = 1**
- 16-bit Q1.15 complex inputs and twiddles
- 22-bit signed internal/output samples with 15 fractional bits
- 100 MHz FPGA clock
- USB-UART interface at 115200 baud
- Verified against NumPy with cocotb
- Implemented and tested on a Nexys A7-100T

**Final timing**

- WNS: **+0.735 ns**
- TNS: **0.000 ns**
- WHS: **+0.148 ns**
- THS: **0.000 ns**
- Setup failing endpoints: **0**
- Hold failing endpoints: **0**

**Final resource use**

- LUTs: **775**
- FFs: **448**
- LUTRAM: **34**
- BRAMs: **3**
- DSP48s: **4**

---

## Architecture

I chose an iterative architecture instead of instantiating a large parallel FFT.

A 64-point radix-2 FFT needs 192 butterfly operations total:

- 6 stages
- 32 butterflies per stage

Instead of using many butterflies in parallel, the design reuses one pipelined
butterfly for the full transform. The butterfly has a 5-cycle latency, but because
it has II = 1, a new butterfly operation can enter every cycle.

The FFT core is built from:

- `fft_controller.sv`
- `fft_address_gen.sv`
- `fft_memory.sv`
- `fft_butterfly.sv`
- `complex_mult.sv`
- `twiddle_rom.sv`
- `bit_reverse.sv`
- `fft_top.sv`

Two sample-memory banks are used in a ping-pong setup. One bank is read during a
stage while the other bank receives butterfly results. The banks swap roles after
each stage.

Input samples are written using bit-reversed addresses. After the sixth stage, the
final bank is read sequentially to output FFT bins 0 through 63.

More detail is in [docs/architecture.md](docs/architecture.md).



---

## Fixed-Point Format

**Inputs and twiddles**

- 16-bit signed
- Q1.15
- Separate real and imaginary components

**Internal and output samples**

- 22-bit signed
- 15 fractional bits
- Extra integer headroom for FFT growth

The Python reference model uses the same fixed-point format so the RTL can be
compared directly against NumPy.

---

## Verification

I verified the design in stages instead of only testing the full FFT at the end.

The cocotb suite covers:

- complex multiplication
- butterfly arithmetic
- 5-cycle butterfly latency
- II = 1 back-to-back butterfly inputs
- bit reversal
- FFT address generation
- twiddle ROM
- ping-pong memory
- FFT controller
- full `fft_top`
- FFT latency
- UART RX integration
- full UART + FFT integration

The full FFT was checked against NumPy using impulse, single-tone, and randomized
complex inputs.

**Numerical results**

- Impulse test: passed
- Single-tone test: passed
- 10 random frames around ±0.1: about 4 real / 3 imag LSB max error
- 10 random frames around ±0.5: about 16 / 16 LSB max error
- 100 full-range legal Q1.15 random frames: about 41 LSB worst observed
  component error in the final regression

The difference from NumPy comes from fixed-point quantization and truncation.

More detail is in
[docs/verification_plan.md](docs/verification_plan.md).

---

## Measured FFT Latency

At 100 MHz:

- First accepted input -> first output: **292 cycles = 2.920 us**
- First accepted input -> last output: **355 cycles = 3.550 us**

These numbers are for the FFT core and do not include UART transfer time.

---

## Hardware Demo

The final board-level path is:

```text
Python GUI / host
        |
        v
USB-UART
        |
        v
uart_rx
        |
        v
uart_sample_assembler
        |
        v
fft_top
        |
        v
uart_fft_serializer
        |
        v
uart_tx
        |
        v
USB-UART
        |
        v
Python / NumPy comparison
```

The host sends 64 complex Q1.15 input samples.

The FPGA computes the FFT and returns 64 complex output bins. Each output bin is
serialized into 6 bytes, so one complete output frame is:

`64 bins x 6 bytes = 384 bytes`

The final hardware test received all **384 bytes** and reconstructed all **64 bins**.

Board controls:

- **BTNC** — start
- **BTND** — reset
- LEDs — start / busy / done

---

## UART Backpressure Bug

One of the more useful bugs showed up only after the FFT was connected to the UART
serializer.

The serializer cannot accept a new FFT bin every clock because it needs time to send
the current bin over UART. That means it applies backpressure to the FFT output.

The first full integration test returned only:

- **63 bins**
- **378 bytes**

instead of 64 bins / 384 bytes.

The problem was that the FFT controller could advance before the delayed synchronous
memory output was aligned with the valid signal.

The fix was to advance the controller only when the downstream interface was ready
and the delayed output data was valid:

```text
controller_ready = output_ready && output_valid_delay
```

After the fix, the full UART regression returned all 384 bytes and the physical FPGA
test returned all 64 bins correctly.

---

## Repository Structure

```text
fpga-fft-accelerator/
├── rtl/          # Synthesizable SystemVerilog
├── cocotb/       # Automated Python/cocotb tests
├── tb_sv/        # Directed SystemVerilog testbenches
├── python/       # Fixed-point + NumPy reference model
├── host/         # UART hardware test + GUI
├── constraints/  # Nexys A7 constraints
├── scripts/      # Utility scripts
├── docs/         # Architecture, verification, implementation results
└── README.md
```

---

## Main Files

**RTL**

- `rtl/fft_top.sv`
- `rtl/fft_controller.sv`
- `rtl/fft_address_gen.sv`
- `rtl/fft_memory.sv`
- `rtl/fft_butterfly.sv`
- `rtl/complex_mult.sv`
- `rtl/twiddle_rom.sv`
- `rtl/bit_reverse.sv`
- `rtl/uart_rx.sv`
- `rtl/uart_sample_assembler.sv`
- `rtl/uart_fft_serializer.sv`
- `rtl/uart_tx.sv`
- `rtl/fft_board_top.sv`

**Host**

- `host/fft_gui.py`
- `host/uart_fft_hardware_test.py`

**Reference model**

- `python/fft_reference.py`
- `python/fixed_point.py`

---

## FPGA Implementation

Target board: **Digilent Nexys A7-100T**

Target clock: **100 MHz**

Final implementation closed timing with positive setup and hold slack.

Full implementation results are in
[docs/implementation_results.md](docs/implementation_results.md).

---

## Tools

- SystemVerilog
- Python
- cocotb
- NumPy
- Icarus Verilog
- AMD Vivado
- Nexys A7-100T
- USB-UART
