# Implementation Results

## Target

- Board: **Digilent Nexys A7-100T**
- Clock: **100 MHz**
- Tool: **AMD Vivado**
- Final board top: `fft_board_top`

---

## Timing

The final routed design closes timing at 100 MHz.

- WNS: **+0.735 ns**
- TNS: **0.000 ns**
- Setup failing endpoints: **0**
- WHS: **+0.148 ns**
- THS: **0.000 ns**
- Hold failing endpoints: **0**

Positive WNS and WHS mean the final design has setup and hold margin.
There are no setup or hold timing violations.

---

## Address Generator Timing Closure

The initial implementation of `fft_address_gen.sv` used generic
stage-dependent arithmetic to calculate the butterfly and twiddle addresses:

```text
H = 1 << stage
group = butterfly_count / H
j = butterfly_count % H
group_start = group * 2 * H

addr_a = group_start + j
addr_b = addr_a + H
twiddle_addr = j * 64 / (2 * H)
```

The equations were functionally correct, but `stage` is a runtime signal.
As a result, Vivado synthesized the variable shift, division, modulo, and
multiplication into a deep combinational path.

Initial post-route timing at the 100 MHz target showed:

- WNS: **-11.100 ns**
- TNS: **-676.130 ns**
- Logic levels: **35**
- Fanout: **121**
- Worst path delay: **~20.77 ns**

The worst path originated from:

```text
controller/stage_count_reg[1]
```

and propagated through the stage-dependent address-generation logic in
`fft_address_gen.sv`.

A 64-point radix-2 FFT has only six stages, so the generic arithmetic was
replaced with a 6-way `case(stage)` implementation. Each stage uses fixed
bit slices, concatenations, constant shifts, and simple additions instead
of variable division, modulo, and multiplication.

Conceptually:

```text
Before:

stage
  |
  v
variable shift / divide / modulo / multiply
  |
  v
35-level combinational path
  |
  v
FAIL 100 MHz


After:

stage
  |
  v
6-way case
  |
  v
constant wiring + simple arithmetic
  |
  v
PASS 100 MHz
```

After rewriting the address generator, timing improved to:

- WNS: **+0.930 ns**
- TNS: **0.000 ns**
- WHS: **+0.156 ns**
- Failing endpoints: **0**

The optimized FFT therefore met the 10 ns clock requirement. After UART
receive/transmit logic, sample assembly, serialization, and the board wrapper
were integrated, the final `fft_board_top` still closed timing at 100 MHz
with **+0.735 ns WNS**.

---

## Resource Use

- LUTs: **775**
- FFs: **448**
- LUTRAM: **34**
- BRAMs: **3**
- DSP48s: **4**
- I/O: **8**

The resource count stays relatively small because the FFT reuses one pipelined
butterfly instead of instantiating a large parallel butterfly network.

---

## FFT Latency

Measured with cocotb at 100 MHz:

- First accepted input -> first output:
  **292 cycles = 2.920 us**
- First accepted input -> last output:
  **355 cycles = 3.550 us**

These are FFT-core numbers and do not include UART transfer time.

---

## UART Output Size

Each FFT result has 64 complex bins.

Each bin is serialized into 6 bytes.

```text
64 bins x 6 bytes = 384 bytes
```

The final physical test received all **384 bytes**.

---

## UART Throughput and End-to-End Timing

The FPGA operates at 100 MHz and completes a 64-point FFT in 355 cycles
(3.55 us from the first accepted sample to the final output).

The hardware demonstration uses a 115200-baud UART configured for 8-N-1
communication. Including the UART start and stop bits, each byte requires
10 transmitted bits.

Each input frame contains 64 complex Q1.15 samples:

- 4 bytes per input sample
- 256 bytes per input frame
- approximately 22.22 ms UART transfer time

Each output frame contains 64 complex 22-bit FFT bins:

- 6 bytes per output bin
- 384 bytes per output frame
- approximately 33.33 ms UART transfer time

The total UART wire time for one complete input/output transaction is
therefore approximately 55.56 ms, compared with only 3.55 us of FFT
computation.

As a result, the current hardware demo is limited primarily by the
115200-baud UART interface rather than FFT computation throughput.

---

## Final Hardware Path

```text
Python host
-> USB-UART
-> FPGA receive path
-> 64-point FFT
-> FPGA transmit path
-> USB-UART
-> Python / NumPy comparison
```

The full path was tested on the Nexys A7-100T and all 64 output bins were returned
correctly.