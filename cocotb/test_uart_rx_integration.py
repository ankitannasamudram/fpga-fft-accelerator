import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer



# Timing parameters


CLK_PERIOD_NS = 10
BAUD_RATE = 115200

# One UART bit lasts approximately 8.68 us
BIT_TIME_NS = int(1e9 / BAUD_RATE)



# UART transmitter helper
#
# This pretends Python is a UART transmitter connected
# to the FPGA uart_rx pin.


async def send_uart_byte(dut, byte):

    # Start bit
    dut.uart_rx.value = 0
    await Timer(BIT_TIME_NS, unit="ns")

    # UART sends data LSB first
    for bit_index in range(8):

        bit_value = (byte >> bit_index) & 1

        dut.uart_rx.value = bit_value

        await Timer(BIT_TIME_NS, unit="ns")

    # Stop bit
    dut.uart_rx.value = 1
    await Timer(BIT_TIME_NS, unit="ns")



# Send one complete complex FFT sample
#
# Protocol:
#
# byte 0 -> real[7:0]
# byte 1 -> real[15:8]
# byte 2 -> imag[7:0]
# byte 3 -> imag[15:8]


async def send_complex_sample(dut, real_value, imag_value):

    # Convert to unsigned 16-bit representation.
    #
    # This is important for negative signed values.
    #
  
    #
    real_u16 = real_value & 0xFFFF
    imag_u16 = imag_value & 0xFFFF

    real_low  = real_u16 & 0xFF
    real_high = (real_u16 >> 8) & 0xFF

    imag_low  = imag_u16 & 0xFF
    imag_high = (imag_u16 >> 8) & 0xFF

    await send_uart_byte(dut, real_low)
    await send_uart_byte(dut, real_high)
    await send_uart_byte(dut, imag_low)
    await send_uart_byte(dut, imag_high)



# Convert a 16-bit unsigned number back into signed
#


def signed16(value):

    value &= 0xFFFF

    if value & 0x8000:
        return value - 0x10000

    return value



# Main test


@cocotb.test()
async def test_64_uart_samples(dut):

    
    # Start 100 MHz FPGA clock
    

    cocotb.start_soon(
        Clock(
            dut.clk,
            CLK_PERIOD_NS,
            unit="ns"
        ).start()
    )


    
    # Initial values
    

    dut.reset.value = 1

    # UART idle state is logic 1
    dut.uart_rx.value = 1


    
    # Hold reset for a few clocks
    

    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.reset.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)


    
    # Generate 64 known complex samples
    #
    # Keep the values simple for this integration test.
    #
    # sample 0:
    # real = 0
    # imag = 0
    #
    # sample 1:
    # real = 1
    # imag = -1
    #
    # ...
    

    expected_samples = []

    for i in range(64):

        real_value = i

        imag_value = -i

        expected_samples.append(
            (real_value, imag_value)
        )


    
    # Receiver/checker coroutine
    #
    # This watches sample_valid while the transmitter
    # simultaneously sends serial UART data.
    

    async def check_samples():

        received_count = 0

        while received_count < 64:

            await RisingEdge(dut.clk)

            if dut.sample_valid.value == 1:

                real_received = signed16(
                    int(dut.sample_real.value)
                )

                imag_received = signed16(
                    int(dut.sample_imag.value)
                )

                expected_real, expected_imag = \
                    expected_samples[received_count]

                assert real_received == expected_real, (
                    f"Sample {received_count}: "
                    f"real expected {expected_real}, "
                    f"got {real_received}"
                )

                assert imag_received == expected_imag, (
                    f"Sample {received_count}: "
                    f"imag expected {expected_imag}, "
                    f"got {imag_received}"
                )

                dut._log.info(
                    f"Sample {received_count:02d}: "
                    f"real={real_received:6d}, "
                    f"imag={imag_received:6d}"
                )

                received_count += 1


    
    # Start checker first
    

    checker = cocotb.start_soon(
        check_samples()
    )


    
    # Send all 64 complex samples over UART
    

    for real_value, imag_value in expected_samples:

        await send_complex_sample(
            dut,
            real_value,
            imag_value
        )


    
    # Wait until checker receives all 64 samples
    

    await checker


    dut._log.info(
        "PASS: all 64 UART complex samples assembled correctly"
    )