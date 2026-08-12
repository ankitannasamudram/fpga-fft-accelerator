import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
import random


@cocotb.test()
async def test_fft_memory(dut):
    cocotb.log.info("fft_memory cocotb test")

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    dut.port_a_we.value = 0
    dut.port_b_we.value = 0

    dut.port_a_addr.value = 0
    dut.port_b_addr.value = 0

    dut.port_a_wreal.value = 0
    dut.port_a_wimag.value = 0
    dut.port_b_wreal.value = 0
    dut.port_b_wimag.value = 0

    await FallingEdge(dut.clk)
    dut.port_a_addr.value = 5
    dut.port_a_wreal.value = 12345
    dut.port_a_wimag.value = -6789
    dut.port_a_we.value = 1

    # write happens here
    await RisingEdge(dut.clk)


    # disable writing before the next clock
    await FallingEdge(dut.clk)
    dut.port_a_we.value = 0
    dut.port_a_addr.value = 5

    # synchronous read happens here

    await RisingEdge(dut.clk)

    await ReadOnly()
    assert dut.port_a_rreal.value.to_signed() == 12345
    assert dut.port_a_rimag.value.to_signed() == -6789

    await FallingEdge(dut.clk)
    dut.port_b_addr.value = 12
    dut.port_b_wreal.value = -22222
    dut.port_b_wimag.value = 33333
    dut.port_b_we.value = 1
    
    # write happens here
    await RisingEdge(dut.clk)
    
    
    # disable writing before the next clock
    await FallingEdge(dut.clk)
    dut.port_b_we.value = 0
    dut.port_b_addr.value = 12
    
    # synchronous read happens here
    
    await RisingEdge(dut.clk)
    
    await ReadOnly()
    assert dut.port_b_rreal.value.to_signed() == -22222
    assert dut.port_b_rimag.value.to_signed() == 33333




    ## this is a synchronous test both port a and b

    await FallingEdge(dut.clk)
    dut.port_a_addr.value = 20
    dut.port_a_wreal.value = 11111
    dut.port_a_wimag.value = -11111
    dut.port_a_we.value = 1



    dut.port_b_addr.value = 40
    dut.port_b_wreal.value = -20000
    dut.port_b_wimag.value = 20000
    dut.port_b_we.value = 1
        
    # write happens here
    await RisingEdge(dut.clk)
        
        
    # disable writing before the next clock
    await FallingEdge(dut.clk)
    dut.port_a_we.value = 0
    dut.port_a_addr.value = 20
    dut.port_b_we.value = 0
    dut.port_b_addr.value = 40
        
    # synchronous read happens here
        
    await RisingEdge(dut.clk)
        
    await ReadOnly()
    assert dut.port_a_rreal.value.to_signed() == 11111
    assert dut.port_a_rimag.value.to_signed() == -11111
    assert dut.port_b_rreal.value.to_signed() == -20000
    assert dut.port_b_rimag.value.to_signed() == 20000

    await FallingEdge(dut.clk)

    ref_real = [0] * 64
    ref_imag = [0] * 64

    def update_ref_memory(ref_real, ref_imag,
                      a_we, a_addr, a_real, a_imag,
                      b_we, b_addr, b_real, b_imag):

        if a_we:
            ref_real[a_addr] = a_real
            ref_imag[a_addr] = a_imag

        if b_we:
            ref_real[b_addr] = b_real
            ref_imag[b_addr] = b_imag

    for addr in range(0, 64, 2):

        await FallingEdge(dut.clk)

        # Port A writes even address
        dut.port_a_addr.value = addr
        dut.port_a_wreal.value = 0
        dut.port_a_wimag.value = 0
        dut.port_a_we.value = 1

        # Port B writes following odd address
        dut.port_b_addr.value = addr + 1
        dut.port_b_wreal.value = 0
        dut.port_b_wimag.value = 0
        dut.port_b_we.value = 1

        await RisingEdge(dut.clk)


    await FallingEdge(dut.clk)

    dut.port_a_we.value = 0
    dut.port_b_we.value = 0


   
    # 200 random cycles
   

    for cycle in range(200):

        await FallingEdge(dut.clk)

        # Random addresses from 0-63
        a_addr = random.randrange(64)
        b_addr = random.randrange(64)

        # Randomly decide whether each port writes
        a_we = random.randint(0, 1)
        b_we = random.randint(0, 1)

        # Avoid both ports writing same address
        if a_we and b_we and a_addr == b_addr:
            b_addr = (b_addr + 1) % 64


        # Random signed 22-bit values
        a_real = random.randint(
            -(1 << 21),
            (1 << 21) - 1
        )

        a_imag = random.randint(
            -(1 << 21),
            (1 << 21) - 1
        )

        b_real = random.randint(
            -(1 << 21),
            (1 << 21) - 1
        )

        b_imag = random.randint(
            -(1 << 21),
            (1 << 21) - 1
        )


        # These are taken BEFORE updating
        # the Python memory with this cycle's
        # writes.
   

        expected_a_real = ref_real[a_addr]
        expected_a_imag = ref_imag[a_addr]

        expected_b_real = ref_real[b_addr]
        expected_b_imag = ref_imag[b_addr]


      
        # Drive DUT inputs
 
        dut.port_a_addr.value = a_addr
        dut.port_a_wreal.value = a_real
        dut.port_a_wimag.value = a_imag
        dut.port_a_we.value = a_we

        dut.port_b_addr.value = b_addr
        dut.port_b_wreal.value = b_real
        dut.port_b_wimag.value = b_imag
        dut.port_b_we.value = b_we


        
        # Memory operates on rising edge
        

        await RisingEdge(dut.clk)
        await ReadOnly()


        
        # Check synchronous read outputs
        

        assert dut.port_a_rreal.value.to_signed() == expected_a_real, (
            f"Cycle {cycle}: Port A real mismatch "
            f"addr={a_addr}"
        )

        assert dut.port_a_rimag.value.to_signed() == expected_a_imag, (
            f"Cycle {cycle}: Port A imag mismatch "
            f"addr={a_addr}"
        )

        assert dut.port_b_rreal.value.to_signed() == expected_b_real, (
            f"Cycle {cycle}: Port B real mismatch "
            f"addr={b_addr}"
        )

        assert dut.port_b_rimag.value.to_signed() == expected_b_imag, (
            f"Cycle {cycle}: Port B imag mismatch "
            f"addr={b_addr}"
        )


        
        # Update Python memory AFTER checking
        # the read results
        

        update_ref_memory(
            ref_real,
            ref_imag,

            a_we,
            a_addr,
            a_real,
            a_imag,

            b_we,
            b_addr,
            b_real,
            b_imag
        )


    cocotb.log.info(
        "PASS: 200 random dual-port memory cycles"
    )

    




    





    
            












