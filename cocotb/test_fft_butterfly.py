import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly

import random


@cocotb.test()
async def test_refmodel_complextest(dut):
    cocotb.log.info("fft_butterfly cocotb test ")
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())


# helper function round_shift and saturate to use the same rounding and approximation model as the hardware is doing
    def round_shift(value):
        FRAC_W = 15
        round_offset = 1 << (FRAC_W-1)
        if value < 0:
            mag = abs(value)
            shifted = (mag+round_offset) >> 15
            return -(shifted)

        else:
            return (value+round_offset) >> 15

    def saturate(value):
        SAMPLE_W = 22

        maximum = (1 << (SAMPLE_W - 1)) - 1
        minimum = -(1 << (SAMPLE_W - 1))
        if value > maximum:
            return maximum
        elif value < minimum:
            return minimum
        else:
            return value

    def reference_model(a_real, a_imag, b_real, b_imag, w_real, w_imag):
        raw_mult_real = b_real * w_real - b_imag * w_imag
        raw_mult_imag = b_real * w_imag + b_imag * w_real

        mult_real = saturate(round_shift(raw_mult_real))
        mult_imag = saturate(round_shift(raw_mult_imag))

        y0_real = saturate(a_real + mult_real)
        y0_imag = saturate(a_imag + mult_imag)

        y1_real = saturate(a_real - mult_real)
        y1_imag = saturate(a_imag - mult_imag)

        return y0_real, y0_imag, y1_real, y1_imag