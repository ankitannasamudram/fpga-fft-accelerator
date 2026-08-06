`timescale 1ns/1ps

interface fft_butterfly_if #(
    parameter int SAMPLE_W  = fft_pkg::SAMPLE_W,
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W
) (
    input logic clk
);

    logic reset;
    logic valid_in;

    logic signed [SAMPLE_W-1:0] a_real;
    logic signed [SAMPLE_W-1:0] a_imag;
    logic signed [SAMPLE_W-1:0] b_real;
    logic signed [SAMPLE_W-1:0] b_imag;

    logic signed [TWIDDLE_W-1:0] w_real;
    logic signed [TWIDDLE_W-1:0] w_imag;

    logic valid_out;

    logic signed [SAMPLE_W-1:0] y0_real;
    logic signed [SAMPLE_W-1:0] y0_imag;
    logic signed [SAMPLE_W-1:0] y1_real;
    logic signed [SAMPLE_W-1:0] y1_imag;

    modport DUT (
        input  clk,
        input  reset,
        input  valid_in,
        input  a_real,
        input  a_imag,
        input  b_real,
        input  b_imag,
        input  w_real,
        input  w_imag,

        output valid_out,
        output y0_real,
        output y0_imag,
        output y1_real,
        output y1_imag
    );

    modport TB (
        input  clk,
        output reset,
        output valid_in,
        output a_real,
        output a_imag,
        output b_real,
        output b_imag,
        output w_real,
        output w_imag,

        input valid_out,
        input y0_real,
        input y0_imag,
        input y1_real,
        input y1_imag
    );

endinterface


module fft_butterfly_tb;

    localparam int SAMPLE_W = fft_pkg::SAMPLE_W;
    localparam int FRAC_W   = fft_pkg::FRAC_W;

    localparam int ONE = 1 <<< FRAC_W;

    localparam int SAMPLE_MAX = (1 <<< (SAMPLE_W-1)) - 1;
    localparam int SAMPLE_MIN = -(1 <<< (SAMPLE_W-1));

    logic clk;

    fft_butterfly_if intf(clk);

    fft_butterfly dut (
        .clk       (clk),
        .reset     (intf.reset),
        .valid_in  (intf.valid_in),

        .a_real    (intf.a_real),
        .a_imag    (intf.a_imag),
        .b_real    (intf.b_real),
        .b_imag    (intf.b_imag),

        .w_real    (intf.w_real),
        .w_imag    (intf.w_imag),

        .valid_out (intf.valid_out),

        .y0_real   (intf.y0_real),
        .y0_imag   (intf.y0_imag),
        .y1_real   (intf.y1_real),
        .y1_imag   (intf.y1_imag)
    );


    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    task automatic reset_dut;
        begin
            intf.reset    = 1'b1;
            intf.valid_in = 1'b0;

            intf.a_real = '0;
            intf.a_imag = '0;
            intf.b_real = '0;
            intf.b_imag = '0;
            intf.w_real = '0;
            intf.w_imag = '0;

            repeat (2) @(posedge clk);

            @(negedge clk);
            intf.reset = 1'b0;
        end
    endtask


    task automatic send_transaction(
        input integer a_r,
        input integer a_i,
        input integer b_r,
        input integer b_i,
        input integer w_r,
        input integer w_i
    );
        begin
            @(negedge clk);

            intf.a_real = a_r;
            intf.a_imag = a_i;
            intf.b_real = b_r;
            intf.b_imag = b_i;
            intf.w_real = w_r;
            intf.w_imag = w_i;

            intf.valid_in = 1'b1;

            @(negedge clk);
            intf.valid_in = 1'b0;
        end
    endtask


    task automatic check_outputs(
        input integer expected_y0_real,
        input integer expected_y0_imag,
        input integer expected_y1_real,
        input integer expected_y1_imag,
        input string  test_name
    );
        begin
            while (intf.valid_out !== 1'b1) begin
                @(posedge clk);
                #1;
            end

            assert ($signed(intf.y0_real) == expected_y0_real)
            else begin
                $error(
                    "%s: y0_real incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y0_real,
                    $signed(intf.y0_real)
                );
            end

            assert ($signed(intf.y0_imag) == expected_y0_imag)
            else begin
                $error(
                    "%s: y0_imag incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y0_imag,
                    $signed(intf.y0_imag)
                );
            end

            assert ($signed(intf.y1_real) == expected_y1_real)
            else begin
                $error(
                    "%s: y1_real incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y1_real,
                    $signed(intf.y1_real)
                );
            end

            assert ($signed(intf.y1_imag) == expected_y1_imag)
            else begin
                $error(
                    "%s: y1_imag incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y1_imag,
                    $signed(intf.y1_imag)
                );
            end

            $display("%s PASSED", test_name);

           
        end
    endtask


    task automatic check_next_output(
        input integer expected_y0_real,
        input integer expected_y0_imag,
        input integer expected_y1_real,
        input integer expected_y1_imag,
        input string  test_name
    );
        begin
            @(posedge clk);
            #1;

            assert (intf.valid_out === 1'b1)
            else begin
                $error("%s: valid_out was not high", test_name);
            end

            assert ($signed(intf.y0_real) == expected_y0_real)
            else begin
                $error(
                    "%s: y0_real incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y0_real,
                    $signed(intf.y0_real)
                );
            end

            assert ($signed(intf.y0_imag) == expected_y0_imag)
            else begin
                $error(
                    "%s: y0_imag incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y0_imag,
                    $signed(intf.y0_imag)
                );
            end

            assert ($signed(intf.y1_real) == expected_y1_real)
            else begin
                $error(
                    "%s: y1_real incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y1_real,
                    $signed(intf.y1_real)
                );
            end

            assert ($signed(intf.y1_imag) == expected_y1_imag)
            else begin
                $error(
                    "%s: y1_imag incorrect. Expected %0d, got %0d",
                    test_name,
                    expected_y1_imag,
                    $signed(intf.y1_imag)
                );
            end

            $display("%s PASSED", test_name);
        end
    endtask


    initial begin
        $dumpfile("build/fft_butterfly_tb.vcd");
        $dumpvars(0, fft_butterfly_tb);

        reset_dut();


       
        // Test 1: All zeros
       

        send_transaction(
            0,
            0,
            0,
            0,
            0,
            -ONE
        );

        check_outputs(
            0,
            0,
            0,
            0,
            "TEST 1 - ALL ZEROS"
        );


       
        // Test 2:
        // A = 3 + j2
        // B = 1 - j1
        // W = -j
        //
        // BW = -1 - j1
        // Y0 = 2 + j1
        // Y1 = 4 + j3
       

        send_transaction(
             3 * ONE,
             2 * ONE,
             1 * ONE,
            -1 * ONE,
             0,
            -1 * ONE
        );

        check_outputs(
            2 * ONE,
            1 * ONE,
            4 * ONE,
            3 * ONE,
            "TEST 2 - NORMAL NEGATIVE J TWIDDLE"
        );


       
        // Test 3:
        // A = -2 + j3
        // B =  2 + j1
        // W = -j
        //
        // BW = 1 - j2
        // Y0 = -1 + j1
        // Y1 = -3 + j5
       

        send_transaction(
            -2 * ONE,
             3 * ONE,
             2 * ONE,
             1 * ONE,
             0,
            -1 * ONE
        );

        check_outputs(
            -1 * ONE,
             1 * ONE,
            -3 * ONE,
             5 * ONE,
            "TEST 3 - MIXED POSITIVE AND NEGATIVE"
        );


       
        // Test 4: Approximate W = 1 + j0
        //
        // Q1.15 cannot represent exactly +1.
        // 32767 represents approximately 0.999969.
        

        send_transaction(
             3 * ONE,
             2 * ONE,
             1 * ONE,
            -1 * ONE,
             32767,
             0
        );

        check_outputs(
            131071,
             32769,
             65537,
             98303,
            "TEST 4 - APPROXIMATE POSITIVE ONE TWIDDLE"
        );


        // Test 5: Positive saturation
        //
        // A = 63
        // B = j2
        // W = -j
        //
        // BW = 2
        // Y0 = 65, which saturates
        // Y1 = 61
        

        send_transaction(
            63 * ONE,
             0,
             0,
             2 * ONE,
             0,
            -1 * ONE
        );

        check_outputs(
            SAMPLE_MAX,
            0,
            61 * ONE,
            0,
            "TEST 5 - POSITIVE SATURATION"
        );


      
        // Test 6: Negative saturation
        
        // A = -63
        // B = -j2
        // W = -j
        
        // BW = -2
        // Y0 = -65, which saturates
        // Y1 = -61
       

        send_transaction(
            -63 * ONE,
              0,
              0,
             -2 * ONE,
              0,
             -1 * ONE
        );

        check_outputs(
            SAMPLE_MIN,
            0,
            -61 * ONE,
            0,
            "TEST 6 - NEGATIVE SATURATION"
        );


       
        // Test 7: Exact latencycheck, Expected butterfly latency = 5 clock edges, counting the input-acceptance edge as cycle 1.
        

        begin
            integer latency_cycles;

            @(negedge clk);

            intf.a_real = 3 * ONE;
            intf.a_imag = 2 * ONE;
            intf.b_real = 1 * ONE;
            intf.b_imag = -1 * ONE;
            intf.w_real = 0;
            intf.w_imag = -1 * ONE;

            intf.valid_in = 1'b1;

            latency_cycles = 0;

            @(posedge clk);
            #1;
            latency_cycles = latency_cycles + 1;

            @(negedge clk);
            intf.valid_in = 1'b0;

            while (intf.valid_out !== 1'b1) begin
                @(posedge clk);
                #1;
                latency_cycles = latency_cycles + 1;
            end

            assert (latency_cycles == 5)
            else begin
                $error(
                    "TEST 7: Expected latency of 5 cycles, got %0d",
                    latency_cycles
                );
            end

            assert ($signed(intf.y0_real) == 2 * ONE);
            assert ($signed(intf.y0_imag) == 1 * ONE);
            assert ($signed(intf.y1_real) == 4 * ONE);
            assert ($signed(intf.y1_imag) == 3 * ONE);

            $display(
                "TEST 7 - EXACT LATENCY PASSED: %0d cycles",
                latency_cycles
            );

            @(posedge clk);
            #1;
        end


       
        // Test 8: Three consecutive transactions
       

        @(negedge clk);

        // Transaction 1: all zeros
        intf.a_real = 0;
        intf.a_imag = 0;
        intf.b_real = 0;
        intf.b_imag = 0;
        intf.w_real = 0;
        intf.w_imag = -ONE;
        intf.valid_in = 1'b1;

        @(negedge clk);

        // Transaction 2
        intf.a_real = 3 * ONE;
        intf.a_imag = 2 * ONE;
        intf.b_real = 1 * ONE;
        intf.b_imag = -1 * ONE;
        intf.w_real = 0;
        intf.w_imag = -ONE;

        @(negedge clk);

        // Transaction 3
        intf.a_real = -2 * ONE;
        intf.a_imag =  3 * ONE;
        intf.b_real =  2 * ONE;
        intf.b_imag =  1 * ONE;
        intf.w_real = 0;
        intf.w_imag = -ONE;

        @(negedge clk);
        intf.valid_in = 1'b0;

        check_outputs(
            0,
            0,
            0,
            0,
            "TEST 8A - CONSECUTIVE TRANSACTION 1"
        );

        check_next_output(
             2 * ONE,
             1 * ONE,
             4 * ONE,
             3 * ONE,
            "TEST 8B - CONSECUTIVE TRANSACTION 2"
        );

        check_next_output(
            -1 * ONE,
             1 * ONE,
            -3 * ONE,
             5 * ONE,
            "TEST 8C - CONSECUTIVE TRANSACTION 3"
        );


        $display("");
        $display("ALL FFT BUTTERFLY DIRECTED TESTS PASSED");
        $display("");

        $finish;
    end

endmodule 