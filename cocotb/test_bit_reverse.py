import cocotb

from cocotb.triggers import Timer


@cocotb.test()
async def test_refmodel_bitreverse(dut):
    cocotb.log.info("bit_reverse for all cases")


    def bit_rev_refmodel(value):
        result = 0

        for i in range(6):
            bit = (value >> i) & 1
            result |= bit << (5 - i)

        return result


    for index in range (64):
        dut.index_in.value = index
        await Timer(1, unit="ns")
        expected_out_addr =  bit_rev_refmodel(index)
        assert int(dut.index_out.value) == expected_out_addr

    dut._log.info("PASS: all 64 bit reversal cases")


        
