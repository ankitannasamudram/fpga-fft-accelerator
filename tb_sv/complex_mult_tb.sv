`timescale 1ns/1ps

interface cmplx_if #(
    parameter int SAMPLE_W  = fft_pkg::SAMPLE_W,
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W
) (
    input logic clk
);

    logic reset;
    logic valid_in;

    logic signed [SAMPLE_W-1:0]  b_real;
    logic signed [SAMPLE_W-1:0]  b_imag;
    logic signed [TWIDDLE_W-1:0] w_real;
    logic signed [TWIDDLE_W-1:0] w_imag;

    logic valid_out;

    logic signed [SAMPLE_W-1:0] t_real;
    logic signed [SAMPLE_W-1:0] t_imag;

endinterface


module complex_mult_tb;

    // Basic clock signal
    logic clk;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Interface instance
    cmplx_if cmplx_if0(clk);

    // DUT instance
    complex_mult c0 (
        .clk       (cmplx_if0.clk),
        .reset     (cmplx_if0.reset),
        .valid_in  (cmplx_if0.valid_in),
        .b_real    (cmplx_if0.b_real),
        .b_imag    (cmplx_if0.b_imag),
        .w_real    (cmplx_if0.w_real),
        .w_imag    (cmplx_if0.w_imag),
        .valid_out (cmplx_if0.valid_out),
        .t_real    (cmplx_if0.t_real),
        .t_imag    (cmplx_if0.t_imag)
    );


    initial begin

        // Generate a VCD waveform file for GTKWave
        $dumpfile("build/complex_mult_tb.vcd");
        $dumpvars(0, complex_mult_tb);

        
        // Reset and initialize all testbench inputs
       

        cmplx_if0.reset    <= 1'b1;
        cmplx_if0.valid_in <= 1'b0;

        cmplx_if0.b_real <= '0;
        cmplx_if0.b_imag <= '0;
        cmplx_if0.w_real <= '0;
        cmplx_if0.w_imag <= '0;

        repeat (2) @(posedge clk);

        cmplx_if0.reset <= 1'b0;

        @(negedge clk);


        // Test 1: multiply by approximately 1 + j0
    
        // B = 0.5 - j0.25
        

        cmplx_if0.w_real <= 16'sd32767;
        cmplx_if0.w_imag <= 16'sd0;

        cmplx_if0.b_real <= 22'sd16384;   // 0.5
        cmplx_if0.b_imag <= -22'sd8192;   // -0.25

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);
        cmplx_if0.valid_in <= 1'b0;

        wait (cmplx_if0.valid_out == 1'b1);
        #1;

        if (cmplx_if0.t_real !== 22'sd16384)
            $error(
                "TEST 1 REAL FAIL: expected 16384, got %0d",
                cmplx_if0.t_real
            );
        else if (cmplx_if0.t_imag !== -22'sd8192)
            $error(
                "TEST 1 IMAG FAIL: expected -8192, got %0d",
                cmplx_if0.t_imag
            );
        else
            $display("PASS: multiply by approximately 1+j0");


        // Test 2: multiply by 0 - j1
       
        // (a + jb)(-j) = b - ja
        
        // B = 0.5 - j0.25
      

        wait (cmplx_if0.valid_out == 1'b0);

        @(negedge clk);

        cmplx_if0.b_real <= 22'sd16384;
        cmplx_if0.b_imag <= -22'sd8192;

        cmplx_if0.w_real <= 16'sd0;
        cmplx_if0.w_imag <= -16'sd32768;

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);
        cmplx_if0.valid_in <= 1'b0;

        wait (cmplx_if0.valid_out == 1'b1);
        #1;

        if (cmplx_if0.t_real !== -22'sd8192)
            $error(
                "TEST 2 REAL FAIL: expected -8192, got %0d",
                cmplx_if0.t_real
            );
        else if (cmplx_if0.t_imag !== -22'sd16384)
            $error(
                "TEST 2 IMAG FAIL: expected -16384, got %0d",
                cmplx_if0.t_imag
            );
        else
            $display("PASS: multiply by 0-j1");


       
        // Test 3: zero input
    
        wait (cmplx_if0.valid_out == 1'b0);

        @(negedge clk);

        cmplx_if0.b_real <= 22'sd0;
        cmplx_if0.b_imag <= 22'sd0;

        cmplx_if0.w_real <= 16'sd23170;
        cmplx_if0.w_imag <= -16'sd23170;

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);
        cmplx_if0.valid_in <= 1'b0;

        wait (cmplx_if0.valid_out == 1'b1);
        #1;

        if (cmplx_if0.t_real !== 22'sd0)
            $error(
                "TEST 3 REAL FAIL: expected 0, got %0d",
                cmplx_if0.t_real
            );
        else if (cmplx_if0.t_imag !== 22'sd0)
            $error(
                "TEST 3 IMAG FAIL: expected 0, got %0d",
                cmplx_if0.t_imag
            );
        else
            $display("PASS: zero input");


    
        // Test 4: back-to-back transactions
       

        wait (cmplx_if0.valid_out == 1'b0);

        @(negedge clk);

        // Transaction 1
        cmplx_if0.b_real <= 22'sd10000;
        cmplx_if0.b_imag <= -22'sd5000;

        cmplx_if0.w_real <= 16'sd32767;
        cmplx_if0.w_imag <= 16'sd0;

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);

        // Transaction 2
        cmplx_if0.b_real <= -22'sd12000;
        cmplx_if0.b_imag <= 22'sd7000;

        cmplx_if0.w_real <= 16'sd32767;
        cmplx_if0.w_imag <= 16'sd0;

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);
        cmplx_if0.valid_in <= 1'b0;

        // First output
        wait (cmplx_if0.valid_out == 1'b1);
        #1;

        if (cmplx_if0.t_real !== 22'sd10000)
            $error(
                "BACK TO BACK 1 REAL FAIL: expected 10000, got %0d",
                cmplx_if0.t_real
            );
        else if (cmplx_if0.t_imag !== -22'sd5000)
            $error(
                "BACK TO BACK 1 IMAG FAIL: expected -5000, got %0d",
                cmplx_if0.t_imag
            );
        else
            $display("PASS: back to back transaction 1");

        // Move to the following output cycle
        @(posedge clk)
        #1;
       
        if (cmplx_if0.valid_out !== 1'b1)
            $error("BACK-TO-BACK VALID FAIL: valid_out was not high for two consecutive cycles");
        else if (cmplx_if0.t_real !== -22'sd12000)
            $error(
                "BACK-TO-BACK 2 REAL FAIL: expected -12000, got %0d",
                cmplx_if0.t_real
            );
        else if (cmplx_if0.t_imag !== 22'sd7000)
            $error(
                "BACK-TO-BACK 2 IMAG FAIL: expected 7000, got %0d",
                cmplx_if0.t_imag
            );
        else
            $display("PASS: back-to-back transaction 2");


        
        // Test 5: positive saturation
    
        // The real result exceeds the maximum signed 22-bit output value and must clamp to 2^21 - 1.
        

        wait (cmplx_if0.valid_out == 1'b0);

        @(negedge clk);

        cmplx_if0.b_real <= 22'sh1FFFFF;
        cmplx_if0.b_imag <= 22'sh200000;

        cmplx_if0.w_real <= 16'sh7FFF;
        cmplx_if0.w_imag <= 16'sh7FFF;

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);
        cmplx_if0.valid_in <= 1'b0;

        wait (cmplx_if0.valid_out == 1'b1);
        #1;

        if (cmplx_if0.t_real !== 22'sh1FFFFF)
            $error(
                "POSITIVE SATURATION FAIL: expected 2097151, got %0d",
                cmplx_if0.t_real
            );
        else
            $display("PASS: positive saturation");


      
        // Test 6: negative saturation
        // The real result is below the minimum signed 22-bit output value and must clamp to -2^21.
       

        wait (cmplx_if0.valid_out == 1'b0);

        @(negedge clk);

        cmplx_if0.b_real <= 22'sh200000;
        cmplx_if0.b_imag <= 22'sh1FFFFF;

        cmplx_if0.w_real <= 16'sh7FFF;
        cmplx_if0.w_imag <= 16'sh7FFF;

        cmplx_if0.valid_in <= 1'b1;

        @(negedge clk);
        cmplx_if0.valid_in <= 1'b0;

        wait (cmplx_if0.valid_out == 1'b1);
        #1;

        if (cmplx_if0.t_real !== 22'sh200000)
            $error(
                "NEGATIVE SATURATION FAIL: expected -2097152, got %0d",
                cmplx_if0.t_real
            );
        else
            $display("PASS: negative saturation");


        $display("All SystemVerilog directed tests completed.");

        $finish;
    end

endmodule