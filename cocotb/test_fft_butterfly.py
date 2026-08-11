import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly

import random


@cocotb.test()
async def test_refmodel_butterflytest(dut):
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

    ONE = 1 << 15

    # Reset
    dut.reset.value = 1
    dut.valid_in.value = 0

    dut.a_real.value = 0
    dut.a_imag.value = 0
    dut.b_real.value = 0
    dut.b_imag.value = 0
    dut.w_real.value = 0
    dut.w_imag.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.reset.value = 0

    # Test values
    a_real = 3 * ONE
    a_imag = 2 * ONE
    b_real = 1 * ONE
    b_imag = -1 * ONE
    w_real = 0
    w_imag = -1 * ONE

    expected = reference_model(
        a_real, a_imag,
        b_real, b_imag,
        w_real, w_imag
    )

    # Drive on falling edge
    await FallingEdge(dut.clk)

    dut.a_real.value = a_real
    dut.a_imag.value = a_imag
    dut.b_real.value = b_real
    dut.b_imag.value = b_imag
    dut.w_real.value = w_real
    dut.w_imag.value = w_imag
    dut.valid_in.value = 1

    # Input is captured here
    await RisingEdge(dut.clk)

    # Turn valid back off
    await FallingEdge(dut.clk)
    dut.valid_in.value = 0

    # We already counted the acceptance edge,
    # so wait 4 more rising edges for 5-cycle latency
    for _ in range(4):
        await RisingEdge(dut.clk)

    await ReadOnly()

    assert dut.valid_out.value == 1

    assert dut.y0_real.value.to_signed() == expected[0]
    assert dut.y0_imag.value.to_signed() == expected[1]
    assert dut.y1_real.value.to_signed() == expected[2]
    assert dut.y1_imag.value.to_signed() == expected[3]
    await FallingEdge(dut.clk)

    expected_queue = []

    for i in range(200):
        a_real = random.randint(-(1 << 21), (1 << 21) - 1)
        a_imag = random.randint(-(1 << 21), (1 << 21) - 1)
        b_real = random.randint(-(1 << 21), (1 << 21) - 1)
        b_imag = random.randint(-(1 << 21), (1 << 21) - 1)

        w_real = random.randint(-(1 << 15), (1 << 15) - 1)
        w_imag = random.randint(-(1 << 15), (1 << 15) - 1)

        expected = reference_model(
            a_real, a_imag,
            b_real, b_imag,
            w_real, w_imag
        )

        expected_queue.append(expected)

        dut.a_real.value = a_real
        dut.a_imag.value = a_imag
        dut.b_real.value = b_real
        dut.b_imag.value = b_imag
        dut.w_real.value = w_real
        dut.w_imag.value = w_imag
        dut.valid_in.value = 1

        await RisingEdge(dut.clk)
        await ReadOnly()

        if int(dut.valid_out.value) == 1:
            actual = (
                dut.y0_real.value.to_signed(),
                dut.y0_imag.value.to_signed(),
                dut.y1_real.value.to_signed(),
                dut.y1_imag.value.to_signed()
            )

            expected = expected_queue.pop(0)

            assert actual == expected, (
                f"Mismatch on transaction {i}\n"
                f"Expected={expected}\n"
                f"Actual={actual}"
            )

        await FallingEdge(dut.clk)

    dut.valid_in.value = 0

    while expected_queue:
        await RisingEdge(dut.clk)
        await ReadOnly()

        if int(dut.valid_out.value) == 1:
            actual = (
                dut.y0_real.value.to_signed(),
                dut.y0_imag.value.to_signed(),
                dut.y1_real.value.to_signed(),
                dut.y1_imag.value.to_signed()
            )

            expected = expected_queue.pop(0)

            assert actual == expected, (
                f"Drain mismatch\n"
                f"Expected={expected}\n"
                f"Actual={actual}"
            )

        await FallingEdge(dut.clk)

    dut._log.info("PASS: 200 back-to-back random butterfly transactions")
