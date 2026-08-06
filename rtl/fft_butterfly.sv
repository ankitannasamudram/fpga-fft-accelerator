`timescale 1ns/1ps

module fft_butterfly #(
    parameter int SAMPLE_W  = fft_pkg::SAMPLE_W,
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W,
    parameter int FRAC_W    = fft_pkg::FRAC_W
) (
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic signed [SAMPLE_W-1:0]  a_real,
    input  logic signed [SAMPLE_W-1:0]  a_imag,
    input  logic signed [SAMPLE_W-1:0]  b_real,
    input  logic signed [SAMPLE_W-1:0]  b_imag,
    input  logic signed [TWIDDLE_W-1:0] w_real,
    input  logic signed [TWIDDLE_W-1:0] w_imag,
    output logic valid_out,
    

    output logic signed [SAMPLE_W-1:0] y0_real,
    output logic signed [SAMPLE_W-1:0] y0_imag,
    output logic signed [SAMPLE_W-1:0] y1_real,
    output logic signed [SAMPLE_W-1:0] y1_imag
);
   
    logic signed [SAMPLE_W-1:0] a1_real;
    logic signed [SAMPLE_W-1:0] a1_imag;
    logic signed [SAMPLE_W-1:0] a2_real;
    logic signed [SAMPLE_W-1:0] a2_imag;
    logic signed [SAMPLE_W-1:0] a3_real;
    logic signed [SAMPLE_W-1:0] a3_imag;
    logic signed [SAMPLE_W-1:0] reg_a_real;
    logic signed [SAMPLE_W-1:0] reg_a_imag;
    logic mult_valid;
    logic signed [SAMPLE_W-1:0] mult_real;
    logic signed [SAMPLE_W-1:0] mult_imag;
    // these are for if the addition goes about 22 bits, if so we clamp them down 
   
    logic signed [SAMPLE_W:0] y0_real_temp;
    logic signed [SAMPLE_W:0] y0_imag_temp;
    logic signed [SAMPLE_W:0] y1_real_temp;
    logic signed [SAMPLE_W:0] y1_imag_temp;

    complex_mult mult_inst (.clk (clk), .reset  (reset), .valid_in  (valid_in), .b_real (b_real), .b_imag (b_imag), .w_real  (w_real), .w_imag (w_imag), .valid_out (mult_valid), .t_real (mult_real), .t_imag (mult_imag));
// this always comb block calculates the addition in 23 bits this is sign extended. Then this is checked for overflow later

    always_comb begin
        y0_real_temp =
            $signed({reg_a_real[SAMPLE_W-1], reg_a_real}) +
            $signed({mult_real[SAMPLE_W-1], mult_real});

        y0_imag_temp =
            $signed({reg_a_imag[SAMPLE_W-1], reg_a_imag}) +
            $signed({mult_imag[SAMPLE_W-1], mult_imag});

        y1_real_temp =
            $signed({reg_a_real[SAMPLE_W-1], reg_a_real}) -
            $signed({mult_real[SAMPLE_W-1], mult_real});

        y1_imag_temp =
            $signed({reg_a_imag[SAMPLE_W-1], reg_a_imag}) -
            $signed({mult_imag[SAMPLE_W-1], mult_imag});
    end


    always_ff @(posedge clk) begin 

        if (reset) begin

            a1_real<= '0 ;
            a1_imag<= '0;
            a2_real<= '0;
            a2_imag<= '0;
            a3_real<= '0;
            a3_imag<= '0;
            reg_a_real<= '0;
            reg_a_imag<= '0;
            y0_imag<='0;
            y0_real<='0;
            y1_imag<='0;
            y1_real<='0;
            valid_out <= 1'b0;
            


        end


        else begin
            a1_real<= a_real;
            a1_imag<= a_imag;
            a2_real<=a1_real;
            a2_imag<= a1_imag;
            a3_real<=a2_real;
            a3_imag<= a2_imag;
            reg_a_real<=a3_real;
            reg_a_imag<= a3_imag;

            // y0_real saturation
            if (y0_real_temp > ((1 <<< (SAMPLE_W-1)) - 1))
                y0_real <= {1'b0, {(SAMPLE_W-1){1'b1}}};
            else if (y0_real_temp < -(1 <<< (SAMPLE_W-1)))
                y0_real <= {1'b1, {(SAMPLE_W-1){1'b0}}};
            else
                y0_real <= y0_real_temp[SAMPLE_W-1:0];


            // y0_imag saturation
            if (y0_imag_temp > ((1 <<< (SAMPLE_W-1)) - 1))
                y0_imag <= {1'b0, {(SAMPLE_W-1){1'b1}}};
            else if (y0_imag_temp < -(1 <<< (SAMPLE_W-1)))
                y0_imag <= {1'b1, {(SAMPLE_W-1){1'b0}}};
            else
                y0_imag <= y0_imag_temp[SAMPLE_W-1:0];


            // y1_real saturation
            if (y1_real_temp > ((1 <<< (SAMPLE_W-1)) - 1))
                y1_real <= {1'b0, {(SAMPLE_W-1){1'b1}}};
            else if (y1_real_temp < -(1 <<< (SAMPLE_W-1)))
                y1_real <= {1'b1, {(SAMPLE_W-1){1'b0}}};
            else
                y1_real <= y1_real_temp[SAMPLE_W-1:0];


            // y1_imag saturation
            if (y1_imag_temp > ((1 <<< (SAMPLE_W-1)) - 1))
                y1_imag <= {1'b0, {(SAMPLE_W-1){1'b1}}};
            else if (y1_imag_temp < -(1 <<< (SAMPLE_W-1)))
                y1_imag <= {1'b1, {(SAMPLE_W-1){1'b0}}};
            else
                y1_imag <= y1_imag_temp[SAMPLE_W-1:0];

            valid_out <= mult_valid;
                    


        end
          










        

    end



endmodule
