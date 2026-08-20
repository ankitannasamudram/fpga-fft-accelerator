import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer
import numpy as np
import math


CLK_FREQ = 100_000_000
BAUD_RATE = 115_200
CLKS_PER_BIT = CLK_FREQ // BAUD_RATE
BIT_TIME_NS = CLKS_PER_BIT * 10


# this task acts like the PC UART transmitter
# it sends one UART byte into the FPGA uart_rx pin
async def send_uart_byte(dut, byte):

    # UART start bit is low
    dut.uart_rx.value = 0
    await Timer(BIT_TIME_NS, unit="ns")

    # send the 8 data bits LSB first
    for i in range(8):
        dut.uart_rx.value = (byte >> i) & 1
        await Timer(BIT_TIME_NS, unit="ns")

    # UART stop bit is high
    dut.uart_rx.value = 1
    await Timer(BIT_TIME_NS, unit="ns")


# each complex FFT sample needs 4 UART bytes
# byte 0 = real low
# byte 1 = real high
# byte 2 = imag low
# byte 3 = imag high
async def send_complex_sample(dut, real_value, imag_value):

    # keep only the lower 16 bits so negative python integers
    # are represented using their 16 bit two's complement form
    real_value = real_value & 0xFFFF
    imag_value = imag_value & 0xFFFF

    # split the 16 bit real value into two 8 bit UART bytes
    real_low = real_value & 0xFF
    real_high = (real_value >> 8) & 0xFF

    # split the 16 bit imaginary value into two 8 bit UART bytes
    imag_low = imag_value & 0xFF
    imag_high = (imag_value >> 8) & 0xFF

    # send the four bytes in the order expected by the assembler
    await send_uart_byte(dut, real_low)
    await send_uart_byte(dut, real_high)
    await send_uart_byte(dut, imag_low)
    await send_uart_byte(dut, imag_high)


@cocotb.test()
async def test_uart_fft_top(dut):

    # start the 100 MHz FPGA clock
    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    # use the same tone test that already passed in fft_top_test.py
    N = 64
    TOLERANCE = 4
    tone_bin = 5
    amplitude = 0.25

    samples_real = []
    samples_imag = []

    # generate a real cosine tone in Q1.15 format
    for n in range(N):

        angle = 2 * math.pi * tone_bin * n / N
        value = amplitude * math.cos(angle)

        q15_value = round(value * (1 << 15))

        samples_real.append(q15_value)
        samples_imag.append(0)

    # convert the same fixed point samples back into floating point
    # so NumPy can calculate the expected FFT
    samples_complex = (
        np.array(samples_real) / (1 << 15)
        + 1j * np.array(samples_imag) / (1 << 15)
    )

    expected_fft = np.fft.fft(samples_complex)

    # safe initial inputs
    dut.reset.value = 1
    dut.start.value = 0

    # UART sits high when nothing is being transmitted
    dut.uart_rx.value = 1

    # hold reset for a couple clocks
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # release reset on the falling edge
    await FallingEdge(dut.clk)
    dut.reset.value = 0

    # pulse start for one clock
    # this moves the FFT controller from IDLE into LOAD
    await FallingEdge(dut.clk)
    dut.start.value = 1

    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.start.value = 0

    # give the FFT controller a couple cycles to settle into LOAD
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    cocotb.log.info("START pressed, FFT should now be waiting for UART samples")

   

    outputs = []

    # watch for FFT outputs while the UART samples are still being transmitted
    async def collect_outputs():

        while len(outputs) < 64:

            await RisingEdge(dut.clk)
            await ReadOnly()

            if dut.fft_output_valid.value:

                real = dut.fft_output_real.value.to_signed()
                imag = dut.fft_output_imag.value.to_signed()

                # FFT outputs come out sequentially from bin 0 to bin 63
                bin_index = len(outputs)

                outputs.append(
                    (bin_index, real, imag)
                )

                cocotb.log.info(
                    f"bin {bin_index}: real={real}, imag={imag}"
                )


    # start watching the FFT before sending the UART frame
    output_collector = cocotb.start_soon(
        collect_outputs()
    )


    # send all 64 complex samples through the actual UART serial input
    for i in range(64):

        await send_complex_sample(
            dut,
            samples_real[i],
            samples_imag[i]
        )

    cocotb.log.info("PASS: sent all 64 samples through UART")


    # wait until the output collector has captured all 64 FFT bins
    await output_collector

    cocotb.log.info("PASS: captured all 64 FFT outputs")

    # compare the FPGA FFT outputs against NumPy
    max_real_error = 0
    max_imag_error = 0

    for bin_index, dut_real, dut_imag in outputs:

        # NumPy gives floating point FFT values
        # scale them back into the same fixed point scale used by the FPGA
        expected_real = round(
            expected_fft[bin_index].real * (1 << 15)
        )

        expected_imag = round(
            expected_fft[bin_index].imag * (1 << 15)
        )

        error_real = dut_real - expected_real
        error_imag = dut_imag - expected_imag

        max_real_error = max(
            max_real_error,
            abs(error_real)
        )

        max_imag_error = max(
            max_imag_error,
            abs(error_imag)
        )

        cocotb.log.info(
            f"bin {bin_index}: "
            f"DUT=({dut_real}, {dut_imag}) "
            f"REF=({expected_real}, {expected_imag}) "
            f"ERR=({error_real}, {error_imag})"
        )

        assert abs(error_real) <= TOLERANCE, (
            f"bin {bin_index}: "
            f"real DUT={dut_real}, "
            f"REF={expected_real}, "
            f"ERR={error_real}"
        )

        assert abs(error_imag) <= TOLERANCE, (
            f"bin {bin_index}: "
            f"imag DUT={dut_imag}, "
            f"REF={expected_imag}, "
            f"ERR={error_imag}"
        )

    cocotb.log.info(
        f"UART FFT TEST PASSED: "
        f"max real error={max_real_error}, "
        f"max imag error={max_imag_error}"
    )