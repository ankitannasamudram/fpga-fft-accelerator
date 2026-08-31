# Verification

## Approach

I verified the project from the smallest arithmetic blocks up to the full physical
FPGA path.

The main tools were:

- SystemVerilog testbenches
- cocotb
- Python fixed-point utilities
- NumPy FFT
- Vivado
- Nexys A7-100T hardware

I did not use UVM or claim functional-coverage closure. The focus was directed
testing, randomized self-checking tests, numerical comparison, timing checks, and
full hardware validation.

---

## 1. Complex Multiplier

Files:

- `rtl/complex_mult.sv`
- `tb_sv/complex_mult_tb.sv`
- `cocotb/test_complex_mult.py`

Checked:

- signed complex multiplication
- positive and negative values
- real/imaginary cross terms
- fixed-point truncation/alignment

**Result: PASS**

---

## 2. FFT Butterfly

Files:

- `rtl/fft_butterfly.sv`
- `tb_sv/fft_butterfly_tb.sv`
- `cocotb/test_fft_butterfly.py`

Checked:

- butterfly arithmetic
- 5-cycle latency
- valid propagation
- back-to-back inputs
- II = 1 behavior

**Result: PASS**

---

## 3. Bit Reversal

Files:

- `rtl/bit_reverse.sv`
- `cocotb/test_bit_reverse.py`

Checked the full 6-bit input-address mapping used during frame loading.

**Result: PASS**

---

## 4. FFT Address Generator

Files:

- `rtl/fft_address_gen.sv`
- `cocotb/test_address_gen.py`

Checked:

- address A
- address B
- stage-dependent butterfly spacing
- 32 butterflies per stage
- twiddle indexing

**Result: PASS**

---

## 5. Twiddle ROM

Files:

- `rtl/twiddle_rom.sv`
- `cocotb/twiddle_rom_test.py`

Checked:

- Q1.15 twiddle constants
- signed real/imaginary values
- ROM addressing

**Result: PASS**

---

## 6. Ping-Pong Memory

Files:

- `rtl/fft_memory.sv`
- `cocotb/fft_memory_test.py`

Checked:

- read/write behavior
- Bank A / Bank B separation
- stage writeback
- bank swapping behavior

**Result: PASS**

---

## 7. FFT Controller

Files:

- `rtl/fft_controller.sv`
- `cocotb/fft_controller_test.py`

Checked:

- 64-sample load
- six FFT stages
- 32 butterflies per stage
- wait-for-pipeline-drain behavior
- bank swaps
- 64 output bins
- ready/valid output stalls
- DONE behavior

One important check was output backpressure.

When `output_ready` is low, the controller must not move to the next output.

**Result: PASS**

---

## 8. Full FFT Core

Files:

- `rtl/fft_top.sv`
- `cocotb/fft_top_test.py`
- `python/fft_reference.py`
- `python/fixed_point.py`

The full core test checks:

```text
input load
-> bit-reversed write
-> ping-pong memory
-> address generation
-> twiddle selection
-> butterfly pipeline
-> six FFT stages
-> 64 output bins
```

The RTL result is compared against NumPy.

### Impulse

All 64 bins matched the expected constant FFT result.

**Result: PASS**

### Single Tone

Used to check:

- correct FFT bin
- sign/phase behavior
- twiddle use
- output ordering

**Result: PASS**

### Random Frames

Final numerical regressions:

- 10 random frames around ±0.1:
  about 4 real / 3 imag LSB max error
- 10 random frames around ±0.5:
  about 16 / 16 LSB max error
- 100 full-range legal Q1.15 random frames:
  about 41 LSB worst observed component error in the final regression

The remaining difference from NumPy is expected from fixed-point quantization and
truncation.

**Result: PASS**

---

## 9. FFT Latency

File:

- `cocotb/fft_top_latency_test.py`

At 100 MHz:

- First accepted input -> first output:
  **292 cycles = 2.920 us**
- First accepted input -> last output:
  **355 cycles = 3.550 us**

The butterfly itself was separately verified at 5 cycles with II = 1.

**Result: PASS**

---

## 10. UART RX

Files:

- `rtl/uart_rx.sv`
- `tb_sv/uart_rx_tb.sv`

Checked:

- 115200 baud at 100 MHz
- start bit
- 8 data bits
- stop bit
- receive-valid pulse

**Result: PASS**

---

## 11. Sample Assembler

Files:

- `rtl/uart_sample_assembler.sv`
- `tb_sv/uart_sample_assembler_tb.sv`

Checked the conversion of four UART bytes into:

- 16-bit signed real
- 16-bit signed imaginary

**Result: PASS**

---

## 12. UART TX

Files:

- `rtl/uart_tx.sv`
- `tb_sv/uart_tx_tb.sv`

Checked:

- serial framing
- baud timing
- byte transmission
- busy behavior

**Result: PASS**

---

## 13. FFT Output Serializer

Files:

- `rtl/uart_fft_serializer.sv`
- `tb_sv/uart_fft_serializer_tb.sv`

Checked:

- one FFT bin accepted at a time
- six output bytes per bin
- waiting for UART TX
- backpressure toward the FFT

**Result: PASS**

---

## 14. Full UART + FFT Integration

Files:

- `cocotb/test_uart_rx_integration.py`
- `cocotb/uart_top_test.py`
- `rtl/uart_rx_integration.sv`
- `rtl/uart_fft_top.sv`

Expected output:

```text
64 bins x 6 bytes = 384 bytes
```

### Bug Found

The first full UART output test returned:

- **63 bins**
- **378 bytes**

The last bin was lost.

### Cause

The FFT output comes from synchronous memory, so the memory data is delayed.

The controller was able to advance before that delayed data and the output-valid
signal were aligned.

This did not show up when the output consumer was always ready. The UART serializer
introduced backpressure, which exposed it.

### Fix

The controller now advances only when both conditions are true:

```text
controller_ready = output_ready && output_valid_delay
```

That aligned:

- controller output count
- memory output latency
- output valid
- serializer acceptance

After the fix:

- 64 bins received
- 384 bytes received
- full UART regression passed

**Result: PASS**

---

## 15. Physical FPGA Test

Final path:

```text
Python host
-> USB-UART
-> uart_rx
-> uart_sample_assembler
-> fft_top
-> uart_fft_serializer
-> uart_tx
-> USB-UART
-> Python / NumPy comparison
```

The physical Nexys A7 test received all **384 bytes**.

All **64 FFT bins** were reconstructed and compared with NumPy.

The hardware result matched within the expected fixed-point error.

**Result: PASS**

---

## 16. Timing

Final implemented design at 100 MHz:

- WNS: **+0.735 ns**
- TNS: **0.000 ns**
- Setup failing endpoints: **0**
- WHS: **+0.148 ns**
- THS: **0.000 ns**
- Hold failing endpoints: **0**

**Result: PASS**

---

## Final Status

The project is complete because:

- arithmetic blocks pass
- butterfly latency and II = 1 pass
- addressing and memory behavior pass
- controller sequencing and backpressure pass
- full FFT matches NumPy
- randomized regressions pass
- all 64 bins survive UART backpressure
- physical FPGA returns all 384 bytes
- timing closes at 100 MHz
