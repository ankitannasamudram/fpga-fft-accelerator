# Architecture

## Overview

The core is a 64-point iterative radix-2 FFT.

A full 64-point transform has:

- 6 stages
- 32 butterflies per stage
- 192 butterfly operations total

The design reuses one butterfly for all 192 operations instead of building a large
parallel FFT. That keeps the design much smaller while still allowing a new
butterfly to enter the pipeline every cycle.

The butterfly is:

- 5 cycles deep
- fully pipelined
- II = 1

[Open the architecture diagram PDF](./fft_architecture.pdf)

---

## Top-Level Data Path

```text
Python host
    |
    v
USB-UART @ 115200 baud
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

`fft_top` contains the actual FFT core. The UART blocks sit outside of it and handle
board-to-PC communication.

---

## FFT Core

Inside `fft_top`:

```text
                 fft_controller
                 /    |    |   \
                /     |    |    \
               v      v    v     v
       fft_address  memory twiddle output control
           _gen            _rom
              \             /
               \           /
                v         v
             pipelined butterfly
                    |
                    v
             memory writeback
```

The main blocks are:

- `fft_controller.sv`
- `fft_address_gen.sv`
- `fft_memory.sv`
- `fft_butterfly.sv`
- `complex_mult.sv`
- `twiddle_rom.sv`
- `bit_reverse.sv`

---

## Controller

The controller runs the FFT one frame at a time.

Main states:

```text
IDLE -> LOAD -> ISSUE -> WAIT_STAGE -> OUTPUT -> DONE
```

### IDLE

Waits for a new frame.

### LOAD

Accepts 64 complex input samples and writes them into the initial memory bank.

The input address is bit reversed before the write.

### ISSUE

Issues 32 butterflies for the current FFT stage.

Each issued butterfly includes:

- address A
- address B
- twiddle index
- valid
- last-butterfly marker

Because the butterfly has II = 1, the controller can issue butterflies on consecutive
clocks.

### WAIT_STAGE

After butterfly 31 is issued, the controller waits for the pipeline to drain.

When the last result returns, the source and destination memory banks swap roles.

Then the next stage begins.

### OUTPUT

After stage 5 completes, the final memory bank is read sequentially from address 0
through 63.

The output uses ready/valid flow control so the UART serializer can stall the FFT
without losing a bin.

### DONE

Marks the end of the frame and returns the core to idle.

---

## Ping-Pong Memory

The design has two 64-entry complex sample banks.

For each stage:

```text
source bank -> butterfly -> destination bank
```

Then the banks swap.

Conceptually:

```text
Stage 0: Bank A -> Bank B
Stage 1: Bank B -> Bank A
Stage 2: Bank A -> Bank B
Stage 3: Bank B -> Bank A
Stage 4: Bank A -> Bank B
Stage 5: Bank B -> Bank A
```

This prevents butterfly results from overwriting samples that are still needed in
the current stage.

---

## Address Generation

`fft_address_gen.sv` generates the two sample addresses and twiddle index for every
butterfly.

There are always 32 butterfly pairs in one stage, but the spacing between the two
sample addresses changes with the stage.

The generated addresses are pipelined so the writeback address stays aligned with
the delayed butterfly result.

---

## Bit Reversal

Bit reversal is used during **input loading**.

The host sends samples in normal order:

```text
0, 1, 2, 3, ... 63
```

The core writes each sample into the initial memory bank using the bit-reversed
version of that 6-bit index.

Because the input is loaded this way, the final FFT bank can be read sequentially
to produce bins 0 through 63.

There is no separate output bit-reversal pass.

---

## Twiddle ROM

`twiddle_rom.sv` stores the FFT twiddle factors.

Each twiddle has:

- 16-bit signed real component
- 16-bit signed imaginary component
- Q1.15 format

The controller/address logic selects the correct twiddle for each butterfly.

The constants are generated with `scripts/generate_twiddles.py`.

---

## Butterfly

`fft_butterfly.sv` is the main arithmetic datapath.

It performs a radix-2 butterfly using:

- one fixed-point complex multiply
- complex add
- complex subtract

`complex_mult.sv` handles the complex multiplication.

The butterfly latency is 5 cycles, but it is fully pipelined, so a new butterfly can
enter every cycle.

That gives:

- latency = 5 cycles
- initiation interval = 1 cycle

---

## Fixed-Point Format

### Inputs and Twiddles

- 16-bit signed
- Q1.15
- separate real and imaginary values

### Internal and Output Samples

- 22-bit signed
- 15 fractional bits

The wider internal format gives the FFT room to grow across all six stages without
moving the binary point.

---

## Output Path

After the sixth FFT stage, the final memory bank is read in normal bin order.

The path is:

```text
final FFT memory
      |
      v
fft_top output
      |
      v
uart_fft_serializer
      |
      v
uart_tx
```

Each output bin contains:

- 22-bit signed real
- 22-bit signed imaginary

The serializer sends 6 bytes per bin.

```text
64 bins x 6 bytes = 384 bytes
```

---

## Board Integration

Board: **Digilent Nexys A7-100T**

Clock: **100 MHz**

UART: **115200 baud**

Controls:

- BTNC — start
- BTND — reset
- LEDs — start / busy / done

The full hardware wrapper is in `rtl/fft_board_top.sv`.

---

## Why I Used This Architecture

A fully parallel FFT would be faster, but it would use a lot more arithmetic
hardware.

For this project I wanted to focus on:

- pipelining
- resource reuse
- memory scheduling
- fixed-point arithmetic
- control logic
- ready/valid flow control
- real FPGA integration

Using one II=1 butterfly with ping-pong memory made those tradeoffs much more
visible than a purely parallel implementation.
