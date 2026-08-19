`timescale 1ns/1ps

module uart_rx_tb;

    
    // Testbench signals
    

    logic clk;
    logic reset;
    logic uart_rx;

    logic [7:0] rx_data;
    logic       rx_valid;


    
    // DUT instance
    

    uart_rx dut (
        .clk      (clk),
        .reset    (reset),
        .uart_rx  (uart_rx),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );


    
    // 100 MHz testbench clock
    //
    // 10 ns period:
    // 5 ns low + 5 ns high
    

    always #5 clk = ~clk;


    
    // UART transmit task
    //
    // Sends one UART byte using:
    // 115200 baud
    // 8 data bits
    // no parity
    // 1 stop bit
    //
    // UART sends LSB first.
    

    task send_byte(input logic [7:0] data);
        integer i;

        begin
            // Start bit
            uart_rx = 1'b0;
            #8680;

            // Send data bits 0 through 7
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #8680;
            end

            // Stop bit
            uart_rx = 1'b1;
            #8680;
        end
    endtask


    
    // Main test
    

    initial begin

        
        // Initialize
        

        clk     = 1'b0;
        reset   = 1'b1;

        // UART idles high
        uart_rx = 1'b1;

        // Hold reset
        #100;

        reset = 1'b0;

        // Let DUT settle
        #100;


        
        // Test 1: 0x53
        

        fork

            begin
                send_byte(8'h53);
            end

            begin
                @(posedge rx_valid);

                if (rx_data == 8'h53)
                    $display("PASS: received 53");
                else
                    $display("FAIL: expected 53, received %h", rx_data);
            end

        join


        
        // Test 2: 0x00
        

        fork

            begin
                send_byte(8'h00);
            end

            begin
                @(posedge rx_valid);

                if (rx_data == 8'h00)
                    $display("PASS: received 00");
                else
                    $display("FAIL: expected 00, received %h", rx_data);
            end

        join


        
        // Test 3: 0xFF
        

        fork

            begin
                send_byte(8'hFF);
            end

            begin
                @(posedge rx_valid);

                if (rx_data == 8'hFF)
                    $display("PASS: received FF");
                else
                    $display("FAIL: expected FF, received %h", rx_data);
            end

        join


        
        // Test 4: 0xA5
        

        fork

            begin
                send_byte(8'hA5);
            end

            begin
                @(posedge rx_valid);

                if (rx_data == 8'hA5)
                    $display("PASS: received A5");
                else
                    $display("FAIL: expected A5, received %h", rx_data);
            end

        join


        
        // Test 5: Back-to-back byte stream
        

        fork

            begin
                send_byte(8'h12);
                send_byte(8'h34);
                send_byte(8'hAB);
                send_byte(8'hCD);
            end

            begin
                @(posedge rx_valid);
                if (rx_data == 8'h12)
                    $display("PASS: stream byte 0 = 12");
                else
                    $display("FAIL: expected 12, got %h", rx_data);

                @(posedge rx_valid);
                if (rx_data == 8'h34)
                    $display("PASS: stream byte 1 = 34");
                else
                    $display("FAIL: expected 34, got %h", rx_data);

                @(posedge rx_valid);
                if (rx_data == 8'hAB)
                    $display("PASS: stream byte 2 = AB");
                else
                    $display("FAIL: expected AB, got %h", rx_data);

                @(posedge rx_valid);
                if (rx_data == 8'hCD)
                    $display("PASS: stream byte 3 = CD");
                else
                    $display("FAIL: expected CD, got %h", rx_data);
            end

        join


        
        // End simulation
        

        #100;

        $display("UART RX TESTS COMPLETE");

        $finish;

    end

    

endmodule