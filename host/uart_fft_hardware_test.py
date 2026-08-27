import serial
import numpy as np
import math
import time


PORT = "COM4"
BAUD_RATE = 115200

N = 64
TOLERANCE = 4

tone_bin = 5
amplitude = 0.25


def make_input_frame():

    samples_real = []
    samples_imag = []

    # generate the same cosine tone we used in simulation
    for n in range(N):

        angle = 2 * math.pi * tone_bin * n / N
        value = amplitude * math.cos(angle)

        q15_value = round(value * (1 << 15))

        samples_real.append(q15_value)
        samples_imag.append(0)

    return samples_real, samples_imag


def make_uart_input_bytes(samples_real, samples_imag):

    data = bytearray()

    # each complex input sample is 4 bytes
    # real low, real high, imag low, imag high
    for real_value, imag_value in zip(samples_real, samples_imag):

        real_value &= 0xFFFF
        imag_value &= 0xFFFF

        data.append(real_value & 0xFF)
        data.append((real_value >> 8) & 0xFF)

        data.append(imag_value & 0xFF)
        data.append((imag_value >> 8) & 0xFF)

    return data


def signed24(value):

    value &= 0xFFFFFF

    if value & 0x800000:
        return value - 0x1000000

    return value


def decode_fft_outputs(data):

    outputs = []

    # each FFT output bin is 6 bytes
    for bin_index in range(64):

        base = bin_index * 6

        real_low = data[base]
        real_mid = data[base + 1]
        real_high = data[base + 2]

        imag_low = data[base + 3]
        imag_mid = data[base + 4]
        imag_high = data[base + 5]

        real_value = (
            real_low
            | (real_mid << 8)
            | (real_high << 16)
        )

        imag_value = (
            imag_low
            | (imag_mid << 8)
            | (imag_high << 16)
        )

        real_value = signed24(real_value)
        imag_value = signed24(imag_value)

        outputs.append(
            (bin_index, real_value, imag_value)
        )

    return outputs


samples_real, samples_imag = make_input_frame()

samples_complex = (
    np.array(samples_real) / (1 << 15)
    + 1j * np.array(samples_imag) / (1 << 15)
)

expected_fft = np.fft.fft(samples_complex)

uart_data = make_uart_input_bytes(
    samples_real,
    samples_imag
)


print(f"Opening {PORT} at {BAUD_RATE} baud...")

with serial.Serial(
    PORT,
    BAUD_RATE,
    timeout=5
) as ser:

    # remove any old bytes sitting in the serial buffers
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    print()
    print("Frame prepared.")
    print("Press RESET on the Nexys A7 first.")
    print("Then press START on the Nexys A7.")
    input("After pressing START, press Enter here to send the frame...")

    # send all 64 complex samples
    ser.write(uart_data)
    ser.flush()

    print(f"Sent {len(uart_data)} bytes")
    print("Waiting for FFT output...")

    # one complete FFT frame should return 384 bytes
    received = ser.read(384)

    print(f"Received {len(received)} bytes")

    if len(received) != 384:
        raise RuntimeError(
            f"Expected 384 bytes, but received {len(received)}"
        )

    outputs = decode_fft_outputs(received)

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

        print(
            f"bin {bin_index:02d}: "
            f"FPGA=({dut_real:8d}, {dut_imag:8d}) "
            f"REF=({expected_real:8d}, {expected_imag:8d}) "
            f"ERR=({error_real:4d}, {error_imag:4d})"
        )

    print()
    print(
        f"MAX ERROR: "
        f"real={max_real_error}, "
        f"imag={max_imag_error}"
    )

    if (
        max_real_error <= TOLERANCE
        and max_imag_error <= TOLERANCE
    ):
        print("PASS: hardware FFT matches NumPy")
    else:
        print("FAIL: hardware FFT exceeded tolerance")