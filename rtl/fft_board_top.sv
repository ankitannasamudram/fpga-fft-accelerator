`timescale 1ns/1ps

module fft_board_top (
    input  logic clk,
    input  logic btn_start,
    input  logic btn_reset,

    output logic led_start,
    output logic led_busy,
    output logic led_done
);

    
    // Synchronize reset button
    

    logic reset_ff1;
    logic reset_ff2;
    logic core_reset;

    always_ff @(posedge clk or posedge btn_reset) begin
        if (btn_reset) begin
            reset_ff1 <= 1'b1;
            reset_ff2 <= 1'b1;
        end
        else begin
            reset_ff1 <= 1'b0;
            reset_ff2 <= reset_ff1;
        end
    end

    assign core_reset = reset_ff2;


    
    // Synchronize start button + make one-cycle pulse
    

    logic start_ff1;
    logic start_ff2;
    logic start_ff2_d;

    logic start_pulse;

    always_ff @(posedge clk) begin
        if (core_reset) begin
            start_ff1   <= 1'b0;
            start_ff2   <= 1'b0;
            start_ff2_d <= 1'b0;
        end
        else begin
            start_ff1   <= btn_start;
            start_ff2   <= start_ff1;
            start_ff2_d <= start_ff2;
        end
    end

    assign start_pulse = start_ff2 & ~start_ff2_d;


    
    // FFT core signals
    

    logic input_valid;
    logic input_ready;

    logic signed [fft_pkg::INPUT_W-1:0] input_real;
    logic signed [fft_pkg::INPUT_W-1:0] input_imag;

    logic core_busy;
    logic core_done;

    logic output_valid;
    logic output_ready;

    logic [fft_pkg::ADDR_W-1:0] output_bin;

    logic signed [fft_pkg::SAMPLE_W-1:0] output_real;
    logic signed [fft_pkg::SAMPLE_W-1:0] output_imag;


    
    // FFT instance
    

    fft_top fft (
        .clk          (clk),
        .reset        (core_reset),
        .start        (start_pulse),

        .input_valid  (input_valid),
        .input_ready  (input_ready),
        .input_real   (input_real),
        .input_imag   (input_imag),

        .busy         (core_busy),
        .done         (core_done),

        .output_valid (output_valid),
        .output_ready (output_ready),
        .output_bin   (output_bin),
        .output_real  (output_real),
        .output_imag  (output_imag)
    );


    
    // Temporary safe defaults
    //
    // UART will replace these later.
    

    //assign input_valid = 1'b0;
    //assign input_real  = '0;
   // assign input_imag  = '0;

    //assign output_ready = 1'b1;


    // Temporary automatic feeder
//
// Sends 64 zero-valued complex samples into the FFT
// so we can verify the core reaches DONE on hardware.

logic       feed_active;
logic [5:0] feed_count;

always_ff @(posedge clk) begin
    if (core_reset) begin
        feed_active <= 1'b0;
        feed_count  <= 6'd0;
    end
    else begin
        if (start_pulse) begin
            feed_active <= 1'b1;
            feed_count  <= 6'd0;
        end
        else if (feed_active && input_ready) begin
            if (feed_count == 6'd63) begin
                feed_active <= 1'b0;
            end
            else begin
                feed_count <= feed_count + 1'b1;
            end
        end
    end
end

assign input_valid = feed_active;
assign input_real  = '0;
assign input_imag  = '0;

assign output_ready = 1'b1;
    
    // LED indicators
    

    // Turns on when a synchronized start pulse occurs.
    // Stays on until reset.
    always_ff @(posedge clk) begin
        if (core_reset)
            led_start <= 1'b0;
        else if (start_pulse)
            led_start <= 1'b1;
    end


    // Busy directly reflects the FFT core.
    assign led_busy = core_busy;


    // Done is only one clock inside fft_top,
    // so latch it so you can actually see it on an LED.
    always_ff @(posedge clk) begin
        if (core_reset)
            led_done <= 1'b0;
        else if (start_pulse)
            led_done <= 1'b0;
        else if (core_done)
            led_done <= 1'b1;
    end


endmodule