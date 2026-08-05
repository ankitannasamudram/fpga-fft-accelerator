import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly

import random


@cocotb.test()
async def test_refmodel_complextest(dut):
    cocotb.log.info("complex_mult test skeleton")
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # basic test for reset

    dut.reset.value = 1
    dut.valid_in.value = 0
    dut.b_real.value = 0
    dut.b_imag.value = 0
    dut.w_real.value = 0
    dut.w_imag.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    assert dut.valid_out.value == 0

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

        # refernce model that will be compared to for every result produced by the fft

    def reference_model(b_real, b_imag, w_real, w_imag):
        raw_real = b_real * w_real - b_imag * w_imag
        raw_imag = b_real * w_imag + b_imag * w_real
        rounded_real = round_shift(raw_real)
        rounded_imag = round_shift(raw_imag)

        return saturate(rounded_real), saturate(rounded_imag)

    # Check multiply by approximately 1 + j0
    real, imag = reference_model(
        16384,      # 0.5
        -8192,      # -0.25
        32767,      # approximately 1.0
        0
    )

    print("Test 1:", real, imag)

    assert real == 16384
    assert imag == -8192


# Check multiplication by 0 - j1
    real, imag = reference_model(
        16384,
        -8192,
        0,
        -32768
    )

    print("Test 2:", real, imag)

    assert real == -8192
    assert imag == -16384

    for i in range(20):
        b_real = random.randint(-(1 << 21), (1 << 21) - 1)
        b_imag = random.randint(-(1 << 21), (1 << 21) - 1)

        w_real = random.randint(-(1 << 15), (1 << 15) - 1)
        w_imag = random.randint(-(1 << 15), (1 << 15) - 1)
        expected_real, expected_imag = reference_model(
            b_real, b_imag, w_real, w_imag,)

        dut.b_real.value = b_real
        dut.b_imag.value = b_imag
        dut.w_real.value = w_real
        dut.w_imag.value = w_imag
        dut.valid_in.value = 1

        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        for j in range(3):
            await RisingEdge(dut.clk)
        await ReadOnly()  # waiting for it to settls

        assert int(dut.valid_out.value) == 1
        actual_real = dut.t_real.value.to_signed()
        actual_imag = dut.t_imag.value.to_signed()

        assert actual_real == expected_real, (
            f"real mismatch: B=({b_real},{b_imag}) "
            f"W=({w_real},{w_imag}) "
            f"expected={expected_real}, got={actual_real}"
        )
        assert actual_imag == expected_imag, (
            f"imag mismatch: B=({b_real},{b_imag}) "
            f"W=({w_real},{w_imag}) "
            f"expected={expected_imag}, got={actual_imag}"
        )

        await FallingEdge(dut.clk)

    expected_queue = []
    for i in range(200):
        b_real = random.randint(-(1 << 21), (1 << 21) - 1)
        b_imag = random.randint(-(1 << 21), (1 << 21) - 1)

        w_real = random.randint(-(1 << 15), (1 << 15) - 1)
        w_imag = random.randint(-(1 << 15), (1 << 15) - 1)
        expected_real, expected_imag = reference_model(
            b_real, b_imag, w_real, w_imag,)
        expected_queue.append((expected_real, expected_imag))

        dut.b_real.value = b_real
        dut.b_imag.value = b_imag
        dut.w_real.value = w_real
        dut.w_imag.value = w_imag
        dut.valid_in.value = 1

        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:

            actual_real = dut.t_real.value.to_signed()
            actual_imag = dut.t_imag.value.to_signed()

            expected_real, expected_imag = expected_queue.pop(0)
            # Check the real output against the oldest expected real result
            assert actual_real == expected_real, (
                f"real mismatch: expected={expected_real}, "
                f"got={actual_real}"
            )

            # Check the imaginary output against the oldest expected imaginary result
            assert actual_imag == expected_imag, (
                f"imag mismatch: expected={expected_imag}, "
                f"got={actual_imag}"
            )

        await FallingEdge(dut.clk)

    # Stop sending new transactions
    dut.valid_in.value = 0

# Drain the remaining outputs still inside the pipeline
    while expected_queue:
        await RisingEdge(dut.clk)
        await ReadOnly()

    # Only compare when the DUT says the output is valid
        if int(dut.valid_out.value) == 1:
            actual_real = dut.t_real.value.to_signed()
            actual_imag = dut.t_imag.value.to_signed()

        # Get the oldest expected result
            expected_real, expected_imag = expected_queue.pop(0)

        # Check the real output
            assert actual_real == expected_real, (
                f"drain real mismatch: expected={expected_real}, "
                f"got={actual_real}"
            )

        # Check the imaginary output
            assert actual_imag == expected_imag, (
                f"drain imag mismatch: expected={expected_imag}, "
                f"got={actual_imag}"
            )

    # Leave the ReadOnly phase before the next loop iteration
        await FallingEdge(dut.clk)
    dut._log.info("PASS: 200 backtoback random transactions")
