import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
import random
import numpy as np
import math 


@cocotb.test()
async def test_fft_top(dut):
    cocotb.start_soon(
            Clock(dut.clk, 10, unit="ns").start()
        )

   # Safe initial inputs
    dut.reset.value = 1
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.input_real.value = 0
    dut.input_imag.value = 0
    dut.output_ready.value = 1

    # Hold reset for a couple clocks
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Release reset
    await FallingEdge(dut.clk)
    dut.reset.value = 0

    # Pulse start for one clock
    dut.start.value = 1
    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.start.value = 0

    while not dut.input_ready.value:
        await RisingEdge(dut.clk)


    # ---------------------------------------------------------
    # Load 64-point impulse
    #
    # x[0] = 0.5 + j0  -> Q1.15 integer = 16384
    # x[1..63] = 0
    # ---------------------------------------------------------
    for i in range(64):

        await FallingEdge(dut.clk)

        dut.input_valid.value = 1

        if i == 0:
            dut.input_real.value = 16384
            dut.input_imag.value = 0
        else:
            dut.input_real.value = 0
            dut.input_imag.value = 0

        # This rising edge is where the DUT accepts the sample.
        await RisingEdge(dut.clk)


    # Stop sending input samples.
    await FallingEdge(dut.clk)

    dut.input_valid.value = 0
    dut.input_real.value = 0
    dut.input_imag.value = 0

    cocotb.log.info("PASS: loaded all 64 impulse samples")

    outputs = []

    # Collect all 64 output bins
    while len(outputs) < 64:

        await ReadOnly()

        if dut.output_valid.value:
            real = dut.output_real.value.to_signed()
            imag = dut.output_imag.value.to_signed()
            bin_index = int(dut.output_bin.value)

            outputs.append((bin_index, real, imag))

            cocotb.log.info(
                f"bin {bin_index}: real={real}, imag={imag}"
            )

        await RisingEdge(dut.clk)


    for bin_index, real, imag in outputs:

        assert real == 16384, (
                f"bin {bin_index}: expected real=16384, got {real}"
            )

        assert imag == 0, (
                f"bin {bin_index}: expected imag=0, got {imag}"
            )

    cocotb.log.info("PASS: 64-point impulse FFT")


    ## now we will create some numpy modules to compare with
    N = 64
    tone_bin = 5
    amplitude = 0.25

    samples = []

    for n in range(N):
        angle = 2 * math.pi * tone_bin * n / N
        value = amplitude * math.cos(angle)

        q15_value = round(value * (1 << 15))

        samples.append(q15_value) 
    samples_float = np.array(samples) / (1<<15)
    expected_fft = np.fft.fft(samples_float)

    for k in range(64):
        cocotb.log.info(
            f"ref bin {k}: real={expected_fft[k].real}, "
            f"imag={expected_fft[k].imag}"
        )