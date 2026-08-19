`timescale 1ns/1ps

module uart_sample_assembler_tb;

    
    // Testbench signals
    

    logic clk;
    logic reset;

    logic [7:0] rx_data;
    logic       rx_valid;

    logic signed [15:0] sample_real;
    logic signed [15:0] sample_imag;
    logic               sample_valid;


    
    // DUT
    

    uart_sample_assembler dut (
        .clk          (clk),
        .reset        (reset),

        .rx_data      (rx_data),
        .rx_valid     (rx_valid),

        .sample_real  (sample_real),
        .sample_imag  (sample_imag),
        .sample_valid (sample_valid)
    );


    
    // 100 MHz clock
    

    initial clk = 1'b0;

    always #5 clk = ~clk;


    
    // Helper task
    //
    // Mimics one byte coming out of uart_rx:
    // rx_data is valid while rx_valid is high for one clock.
    

    task send_rx_byte(input logic [7:0] data);
        begin
            @(negedge clk);

            rx_data  = data;
            rx_valid = 1'b1;

            @(negedge clk);

            rx_valid = 1'b0;
        end
    endtask


    
    // Main test
    

    initial begin

        
        // Initialize
        

        reset    = 1'b1;
        rx_data  = 8'h00;
        rx_valid = 1'b0;

        // Hold reset for a few clocks
        repeat (3) @(posedge clk);

        reset = 1'b0;

        repeat (2) @(posedge clk);


        
        // Test 1
        //
        // Send:
        //
        // real_low  = 34
        // real_high = 12
        // imag_low  = CD
        // imag_high = AB
        //
        // Expected:
        //
        // real = 1234
        // imag = ABCD
        

        fork

            
            // Transmitter
            
            begin
                send_rx_byte(8'h34);
                send_rx_byte(8'h12);
                send_rx_byte(8'hCD);
                send_rx_byte(8'hAB);
            end


            
            // Checker
            
            begin
                @(posedge sample_valid);

                if (sample_real == 16'h1234)
                    $display("PASS: sample_real = %h", sample_real);
                else
                    $display(
                        "FAIL: expected sample_real = 1234, got %h",
                        sample_real
                    );

                if (sample_imag == 16'hABCD)
                    $display("PASS: sample_imag = %h", sample_imag);
                else
                    $display(
                        "FAIL: expected sample_imag = ABCD, got %h",
                        sample_imag
                    );
            end

        join


        
        // Check that sample_valid is only one clock wide
        

        @(negedge clk);

        if (sample_valid == 1'b0)
            $display("PASS: sample_valid returned low");
        else
            $display("FAIL: sample_valid stayed high");


        
        // Test 2
        //
        // Verify assembler resets byte_count and can build
        // another sample immediately afterward.
        //
        // Bytes:
        //   real = 5678
        //   imag = 9ABC
        

        fork

            begin
                send_rx_byte(8'h78);
                send_rx_byte(8'h56);
                send_rx_byte(8'hBC);
                send_rx_byte(8'h9A);
            end

            begin
                @(posedge sample_valid);

                if ((sample_real == 16'h5678) &&
                    (sample_imag == 16'h9ABC)) begin

                    $display(
                        "PASS: second sample real=%h imag=%h",
                        sample_real,
                        sample_imag
                    );

                end
                else begin

                    $display(
                        "FAIL: second sample real=%h imag=%h",
                        sample_real,
                        sample_imag
                    );

                end
            end

        join


        
        // End simulation
        

        #100;

        $display("UART SAMPLE ASSEMBLER TESTS COMPLETE");

        $finish;

    end

endmodule

