import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
import random


@cocotb.test()
async def test_fft_controller(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    # Initial inputs
    dut.reset.value = 1
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.output_ready.value = 0
    dut.butterfly_valid_out.value = 0
    dut.butterfly_last_out.value = 0
    dut.addr_a.value = 0
    dut.addr_b.value = 0

    # Reset controller
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.reset.value = 0

    # Controller should be idle
    assert dut.busy.value == 0
    assert dut.input_ready.value == 0
    assert dut.issue_read.value == 0

    # Start a new FFT
    dut.start.value = 1

    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.start.value = 0

    assert dut.input_ready.value ==1
    assert dut.busy.value ==1
    assert dut.issue_read.value==0
    assert dut.load_count.value==0

    # this is test to check if 64 load is working and load count value is right 

    dut.input_valid.value = 1

    for index_load in range(64):
        await RisingEdge(dut.clk)
        await ReadOnly()

        if index_load < 63:
            assert dut.load_count.value == index_load + 1
            assert dut.input_ready.value == 1
            assert dut.issue_read.value == 0

        await FallingEdge(dut.clk)

    dut.input_valid.value = 0

    assert dut.load_count.value == 0
    assert dut.issue_read.value == 1
    assert dut.busy.value == 1






    
    # TEST ALL 6 FFT STAGES
    

    expected_bank = 0

    for expected_stage in range(6):

        # We should now be in ISSUE
        assert dut.issue_read.value == 1
        assert int(dut.stage_count.value) == expected_stage
        assert int(dut.butterfly_count.value) == 0
        assert int(dut.source_bank.value) == expected_bank

        # At the instant we first enter the ISSUE state valid_in has not
        # propagated through the 1cycle memory delay yet.
        assert dut.butterfly_valid_in.value == 0

        # Queue used to verify writeback addresses are delayed
        # correctly through the metadata pipeline.
        address_queue = []


        
        # Issue exactly 32 butterflies
        
        for index_issue in range(32):

            # We are already at a falling edge here so drive immediately
            test_addr_a = (index_issue * 2) % 64
            test_addr_b = (test_addr_a + 1) % 64

            dut.addr_a.value = test_addr_a
            dut.addr_b.value = test_addr_b

            address_queue.append((test_addr_a, test_addr_b))

            if index_issue >= 5:
                dut.butterfly_valid_out.value = 1
            else:
                dut.butterfly_valid_out.value = 0

            # This is the clock that actually issues this butterfly
            await RisingEdge(dut.clk)
            await ReadOnly()

            if index_issue < 31:
                assert int(dut.butterfly_count.value) == index_issue + 1
                assert dut.issue_read.value == 1
            else:
                assert int(dut.butterfly_count.value) == 31
                assert dut.issue_read.value == 0

            assert dut.butterfly_valid_in.value == 1

            if index_issue == 31:
                assert dut.butterfly_last_in.value == 1
            else:
                assert dut.butterfly_last_in.value == 0

            if len(address_queue) >= 6:
                expected_addr_a, expected_addr_b = address_queue.pop(0)

                assert int(dut.write_addr_a.value) == expected_addr_a
                assert int(dut.write_addr_b.value) == expected_addr_b
                assert dut.write_enable.value == 1

            # Prepare for driving the next transaction
            await FallingEdge(dut.clk)


        
        
        # Five issued address pairs remain in the metadata pipeline.
        

        for _ in range(5):

            

            dut.butterfly_valid_out.value = 1
            dut.butterfly_last_out.value = 0

            await RisingEdge(dut.clk)
            await ReadOnly()

            # No new butterfly reads during WAIT_STAGE
            assert dut.issue_read.value == 0

            # After one WAIT_STAGE clock, delayed valid/last
            # should clear because no new transaction was issued.
            assert dut.butterfly_valid_in.value == 0
            assert dut.butterfly_last_in.value == 0

            expected_addr_a, expected_addr_b = address_queue.pop(0)

            assert int(dut.write_addr_a.value) == expected_addr_a
            assert int(dut.write_addr_b.value) == expected_addr_b

            assert dut.write_enable.value == 1
            await FallingEdge(dut.clk)


        assert len(address_queue) == 0

        
        dut.butterfly_valid_out.value = 0


        
        # WAIT_STAGE HOLD TEST
        #
        # Delay last_out by a random number of cycles.
        # Controller must not advance early.
        

        saved_stage = int(dut.stage_count.value)
        saved_bank = int(dut.source_bank.value)

        wait_cycles = random.randint(2, 6)

        dut.butterfly_last_out.value = 0

        for _ in range(wait_cycles):

            await RisingEdge(dut.clk)
            await ReadOnly()

            assert dut.issue_read.value == 0
            assert int(dut.butterfly_count.value) == 31
            assert int(dut.stage_count.value) == saved_stage
            assert int(dut.source_bank.value) == saved_bank

            await FallingEdge(dut.clk)


        
        # Tell controller the stages last result has completed
        

        dut.butterfly_last_out.value = 1

        await RisingEdge(dut.clk)
        await ReadOnly()


        # Bank must swap after EVERY stage, including stage 5
        expected_bank ^= 1

        assert int(dut.source_bank.value) == expected_bank


        if expected_stage < 5:
            assert int(dut.stage_count.value) == expected_stage + 1

            # Prepare next stage from butterfly zero
            assert int(dut.butterfly_count.value) == 0

            # FSM should now be back in ISSUE
            assert dut.issue_read.value == 1


        else:

            # Stage 5 is the final FFT stage.
            # Stage counter cannot become 6.
            assert int(dut.stage_count.value) == 5

            # Controller should now be in OUTPUT
            assert dut.issue_read.value == 0
            assert dut.output_valid.value == 1


        await FallingEdge(dut.clk)

        dut.butterfly_last_out.value = 0
        dut.butterfly_valid_out.value = 0


    
    # OUTPUT pressure test 
    

    accepted_outputs = 0

    while accepted_outputs < 64:

        await FallingEdge(dut.clk)

        # Randomly let the downstream side accept/stall
        ready = random.randint(0, 1)

        dut.output_ready.value = ready

        count_before = int(dut.output_count.value)

        assert dut.output_valid.value == 1


        await RisingEdge(dut.clk)
        await ReadOnly()


        if ready:

            accepted_outputs += 1

            if count_before < 63:

                assert int(dut.output_count.value) == count_before + 1

            else:

                # Final output was accepted
                assert count_before == 63

                # Counter resets
                assert int(dut.output_count.value) == 0

                # FSM enters DONE
                assert dut.done.value == 1

        else:

            # Downstream stalled so the  output counter must not move
            assert int(dut.output_count.value) == count_before


    
    # DONE signal must last at least one cycle her 
    

    assert dut.done.value == 1
    assert dut.busy.value == 0
    assert dut.output_valid.value == 0
    assert accepted_outputs == 64


    # DONE -> IDLE on next clock
    await RisingEdge(dut.clk)
    await ReadOnly()

    assert dut.done.value == 0
    assert dut.busy.value == 0
    assert dut.input_ready.value == 0
    assert dut.issue_read.value == 0


    cocotb.log.info(
        "PASS: complete FFT controller sequencing verification"
    )

    





            
