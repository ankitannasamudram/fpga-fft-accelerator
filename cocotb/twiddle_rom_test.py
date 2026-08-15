import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
import math




@cocotb.test()
async def test_refmodel_butterflytest(dut):
    cocotb.log.info("twiddle rom cocotb test ")
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    def q15_quantize(value):
        TWIDDLE_W = 16

        scaled = round(value * (1 << 15))

        maximum = (1 << (TWIDDLE_W - 1)) - 1   # 32767
        minimum = -(1 << (TWIDDLE_W - 1))      # -32768

        if scaled > maximum:
            return maximum
        elif scaled < minimum:
            return minimum
        else:
            return scaled


    def ref_twiddle_model(k):

        angle = 2 * math.pi * k / 64

        w_real = q15_quantize(math.cos(angle))
        w_imag = q15_quantize(-math.sin(angle))

        return w_real, w_imag

    for k_index in range(32):
        await FallingEdge(dut.clk)
        dut.addr.value = k_index
        expected = ref_twiddle_model(k_index)
        await RisingEdge(dut.clk)
        await ReadOnly()

        actual_real = dut.w_real.value.to_signed()
        actual_imag = dut.w_imag.value.to_signed()

        assert actual_real == expected[0]
        assert actual_imag == expected[1]
        

    
        

    

        
