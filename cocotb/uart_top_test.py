import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np
import math


CLK_FREQ = 100_000_000
BAUD_RATE = 115_200
CLKS_PER_BIT = CLK_FREQ // BAUD_RATE
BIT_TIME_NS = CLKS_PER_BIT * 10


# this task acts like the PC UART transmitter
# it sends one UART byte into the FPGA uart_rx pin
async def send_uart_byte(dut, byte):

    # send start bit
    dut.uart_rx.value = 0
    await Timer(BIT_TIME_NS, unit="ns")

    # send 8 data bits LSB first
    for i in range(8):
        dut.uart_rx.value = (byte >> i) & 1
        await Timer(BIT_TIME_NS, unit="ns")

    # send stop bit
    dut.uart_rx.value = 1
    await Timer(BIT_TIME_NS, unit="ns")


# each complex FFT input sample is sent as 4 UART bytes
# real low, real high, imag low, imag high
async def send_complex_sample(dut, real_value, imag_value):

    # convert signed python values into 16 bit two's complement
    real_value = real_value & 0xFFFF
    imag_value = imag_value & 0xFFFF

    real_low = real_value & 0xFF
    real_high = (real_value >> 8) & 0xFF

    imag_low = imag_value & 0xFF
    imag_high = (imag_value >> 8) & 0xFF

    await send_uart_byte(dut, real_low)
    await send_uart_byte(dut, real_high)
    await send_uart_byte(dut, imag_low)
    await send_uart_byte(dut, imag_high)


# this task acts like the PC UART receiver
# it decodes one byte coming from the FPGA uart_tx pin
async def receive_uart_byte(dut):

    # wait for the UART line to go low which means start bit
    while dut.uart_tx.value == 1:
        await RisingEdge(dut.clk)

    # move to the middle of the start bit
    for _ in range(CLKS_PER_BIT // 2):
        await RisingEdge(dut.clk)

    assert dut.uart_tx.value == 0, "Invalid UART start bit"

    # move one full bit time to the middle of data bit 0
    for _ in range(CLKS_PER_BIT):
        await RisingEdge(dut.clk)

    received = 0

    # sample all 8 data bits LSB first
    for i in range(8):

        bit_value = int(dut.uart_tx.value)

        received |= bit_value << i

        for _ in range(CLKS_PER_BIT):
            await RisingEdge(dut.clk)

    # we should now be in the middle of the stop bit
    assert dut.uart_tx.value == 1, "Invalid UART stop bit"

    return received


# convert a 24 bit two's complement number into a signed python integer
def signed24(value):

    value &= 0xFFFFFF

    if value & 0x800000:
        return value - 0x1000000

    return value


# receive the six UART bytes that make up one FFT output bin
async def receive_fft_bin(dut):

    real_low = await receive_uart_byte(dut)
    real_mid = await receive_uart_byte(dut)
    real_high = await receive_uart_byte(dut)

    imag_low = await receive_uart_byte(dut)
    imag_mid = await receive_uart_byte(dut)
    imag_high = await receive_uart_byte(dut)

    # rebuild the original 24 bit sign extended real value
    real_value = (
        real_low
        | (real_mid << 8)
        | (real_high << 16)
    )

    # rebuild the original 24 bit sign extended imaginary value
    imag_value = (
        imag_low
        | (imag_mid << 8)
        | (imag_high << 16)
    )

    real_value = signed24(real_value)
    imag_value = signed24(imag_value)

    return real_value, imag_value


@cocotb.test()
async def test_uart_fft_top(dut):

    # start the 100 MHz FPGA clock
    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    N = 64
    TOLERANCE = 4
    tone_bin = 5
    amplitude = 0.25

    samples_real = []
    samples_imag = []

    # generate the same cosine tone used in the original fft_top test
    for n in range(N):

        angle = 2 * math.pi * tone_bin * n / N
        value = amplitude * math.cos(angle)

        q15_value = round(value * (1 << 15))

        samples_real.append(q15_value)
        samples_imag.append(0)

    # calculate NumPy reference FFT
    samples_complex = (
        np.array(samples_real) / (1 << 15)
        + 1j * np.array(samples_imag) / (1 << 15)
    )

    expected_fft = np.fft.fft(samples_complex)

    # safe initial inputs
    dut.reset.value = 1
    dut.start.value = 0
    dut.uart_rx.value = 1

    # hold reset for a couple clocks
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.reset.value = 0

    # pulse start so fft_top enters the LOAD state
    await FallingEdge(dut.clk)
    dut.start.value = 1

    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.start.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    cocotb.log.info("START pressed, FFT waiting for UART samples")

    outputs = []


    # this runs at the same time as the input UART transmission
    # and waits for FFT results to come back through uart_tx
    async def collect_outputs():

        for bin_index in range(64):

            real, imag = await receive_fft_bin(dut)

            outputs.append(
                (bin_index, real, imag)
            )

            cocotb.log.info(
                f"received bin {bin_index}: "
                f"real={real}, imag={imag}"
            )


    # start listening to uart_tx before we send the input frame
    output_collector = cocotb.start_soon(
        collect_outputs()
    )

    async def watch_done():

        while True:

            await RisingEdge(dut.clk)

            if dut.done.value:
                cocotb.log.info(
                    f"FFT DONE asserted at {cocotb.utils.get_sim_time(unit='ns')} ns"
                )
                return


    done_watcher = cocotb.start_soon(
        watch_done()
    )

        # count every byte that the serializer gives to uart_tx
    async def watch_serializer():

        byte_count = 0

        while byte_count < 384:

            await RisingEdge(dut.clk)

            if dut.serializer.tx_valid.value:

                byte_count += 1

                if byte_count >= 370:
                    cocotb.log.info(
                        f"serializer byte {byte_count}: "
                        f"data=0x{int(dut.serializer.tx_data.value):02X}"
                    )

        cocotb.log.info(
            f"SERIALIZER FINISHED: {byte_count} bytes sent"
        )


    serializer_watcher = cocotb.start_soon(
        watch_serializer()
    )

        # count each time uart_tx starts transmitting a byte
    async def watch_uart_tx():

        transmission_count = 0
        previous_busy = 0

        while transmission_count < 384:

            await RisingEdge(dut.clk)

            current_busy = int(dut.transmitter.tx_busy.value)

            # rising edge of tx_busy means uart_tx accepted a new byte
            if current_busy == 1 and previous_busy == 0:

                transmission_count += 1

                if transmission_count >= 370:
                    cocotb.log.info(
                        f"uart_tx transmission {transmission_count}"
                    )

            previous_busy = current_busy

        cocotb.log.info(
            f"UART_TX FINISHED: {transmission_count} bytes accepted"
        )


    uart_tx_watcher = cocotb.start_soon(
        watch_uart_tx()
    )

        # count every FFT output accepted by the serializer
    async def watch_fft_handshakes():

        handshake_count = 0

        while handshake_count < 64:

            await RisingEdge(dut.clk)

            if dut.fft_output_valid.value and dut.fft_output_ready.value:

                handshake_count += 1

                if handshake_count >= 60:
                    cocotb.log.info(
                        f"FFT HANDSHAKE {handshake_count}: "
                        f"output_count={int(dut.fft_core.output_count.value)}, "
                        f"real={dut.fft_output_real.value.to_signed()}, "
                        f"imag={dut.fft_output_imag.value.to_signed()}"
                    )

        cocotb.log.info(
            f"FFT HANDSHAKES FINISHED: {handshake_count}"
        )


    fft_handshake_watcher = cocotb.start_soon(
        watch_fft_handshakes()
    )


    # send all 64 complex input samples through uart_rx
    for i in range(64):

        await send_complex_sample(
            dut,
            samples_real[i],
            samples_imag[i]
        )

    cocotb.log.info("PASS: sent all 64 input samples through UART")


    # wait until all 64 FFT output bins have come back over uart_tx
    await output_collector

    cocotb.log.info("PASS: received all 64 FFT bins through UART")


    # compare FPGA output against NumPy
    max_real_error = 0
    max_imag_error = 0

    for bin_index, dut_real, dut_imag in outputs:

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
        f"FULL UART FFT TEST PASSED: "
        f"max real error={max_real_error}, "
        f"max imag error={max_imag_error}"
    )