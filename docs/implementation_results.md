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
