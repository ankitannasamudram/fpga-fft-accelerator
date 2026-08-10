import cocotb

from cocotb.triggers import Timer


@cocotb.test()
async def test_refmodel_addresgen(dut):
    cocotb.log.info("fft_address gen for all cases")


    def address_ref_model(stage, butterfly_count):
        H = 1 << stage
        group = butterfly_count // H
        j = butterfly_count % H
        group_start = group * 2 * H
        # these 3 are the only calcs that we will test and care about for this verifcation module
        expected_a = group_start + j
        expected_b = expected_a + H
        expected_twiddle = j * 64 // (2 * H)

        return expected_a, expected_b, expected_twiddle


    for stage in range(6):  # there are stages 0 to 5
        for butterfly_count in range(32):  # there are staged 0 to 31
            dut.stage.value = stage
            dut.butterfly_count.value = butterfly_count
            await Timer(1, unit="ns")

            expected_addr = address_ref_model(stage, butterfly_count)
            assert int(dut.addr_a.value) == expected_addr[0]
            assert int(dut.addr_b.value) == expected_addr[1]
            assert int(dut.twiddle_addr.value) == expected_addr[2]


    dut._log.info("PASS: all 192 address generator cases")
