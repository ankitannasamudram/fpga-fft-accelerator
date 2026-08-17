import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly


@cocotb.test()
async def test_fft_top_latency(dut):

    
    # Start 100 MHz clock
    
    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    
    # Global cycle counter
    
    cycle = 0

    async def count_cycles():
        nonlocal cycle

        while True:
            await RisingEdge(dut.clk)
            cycle += 1

    cocotb.start_soon(count_cycles())

    
    # Initial values
    
    dut.reset.value = 1
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.input_real.value = 0
    dut.input_imag.value = 0

    # Keep output interface always ready
    dut.output_ready.value = 1

    
    # Reset
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.reset.value = 0

    
    # Start one FFT frame
    
    dut.start.value = 1

    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.start.value = 0

    # Wait until controller is ready for input samples
    while not dut.input_ready.value:
        await RisingEdge(dut.clk)

    
    # Load one 64-point impulse
    #
    # x[0] = 0.5 = 16384 in Q1.15
    # all remaining samples = 0
    

    first_input_cycle = None

    for i in range(64):

        await FallingEdge(dut.clk)

        dut.input_valid.value = 1

        if i == 0:
            dut.input_real.value = 16384
        else:
            dut.input_real.value = 0

        dut.input_imag.value = 0

        await RisingEdge(dut.clk)

        # This rising edge accepts the sample
        if i == 0:
            first_input_cycle = cycle

    # Stop driving samples
    await FallingEdge(dut.clk)

    dut.input_valid.value = 0
    dut.input_real.value = 0
    dut.input_imag.value = 0

    
    # Collect output timing
    

    first_output_cycle = None
    last_output_cycle = None

    outputs_received = 0

    while outputs_received < 64:

        await ReadOnly()

        if dut.output_valid.value:

            if first_output_cycle is None:
                first_output_cycle = cycle

            last_output_cycle = cycle

            outputs_received += 1

        await RisingEdge(dut.clk)

    
    # Calculate measured latency
    

    first_output_latency_cycles = (
        first_output_cycle - first_input_cycle
    )

    full_frame_latency_cycles = (
        last_output_cycle - first_input_cycle
    )

    clock_period_ns = 10

    first_output_latency_ns = (
        first_output_latency_cycles * clock_period_ns
    )

    full_frame_latency_ns = (
        full_frame_latency_cycles * clock_period_ns
    )

    first_output_latency_us = (
        first_output_latency_ns / 1000
    )

    full_frame_latency_us = (
        full_frame_latency_ns / 1000
    )

    
    # Throughput
    

    frame_rate = 1 / (
        full_frame_latency_us * 1e-6
    )

    sample_rate = frame_rate * 64

    
    # Print results
    

    cocotb.log.info(
        f"FIRST INPUT CYCLE: {first_input_cycle}"
    )

    cocotb.log.info(
        f"FIRST OUTPUT CYCLE: {first_output_cycle}"
    )

    cocotb.log.info(
        f"LAST OUTPUT CYCLE: {last_output_cycle}"
    )

    cocotb.log.info(
        f"MEASURED FIRST-OUTPUT LATENCY: "
        f"{first_output_latency_cycles} cycles "
        f"= {first_output_latency_us:.3f} us"
    )

    cocotb.log.info(
        f"MEASURED FULL-FRAME LATENCY: "
        f"{full_frame_latency_cycles} cycles "
        f"= {full_frame_latency_us:.3f} us"
    )

    cocotb.log.info(
        f"DERIVED FRAME RATE: "
        f"{frame_rate:.0f} FFT frames/s"
    )

    cocotb.log.info(
        f"DERIVED SAMPLE RATE: "
        f"{sample_rate / 1e6:.3f} MSamples/s"
    )