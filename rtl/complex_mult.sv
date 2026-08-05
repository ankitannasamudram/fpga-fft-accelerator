`timescale 1ns/1ps

module complex_mult #(
    parameter int SAMPLE_W  = fft_pkg::SAMPLE_W,
    parameter int TWIDDLE_W = fft_pkg::TWIDDLE_W,
    parameter int FRAC_W    = fft_pkg::FRAC_W
) (
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic signed [SAMPLE_W-1:0]  b_real,
    input  logic signed [SAMPLE_W-1:0]  b_imag,
    input  logic signed [TWIDDLE_W-1:0] w_real,
    input  logic signed [TWIDDLE_W-1:0] w_imag,
    output logic valid_out,
    output logic signed [SAMPLE_W-1:0] t_real,
    output logic signed [SAMPLE_W-1:0] t_imag
);
   
    // TODO: implement pipelined fixed-point T = B * W.
    logic valid_stage1;
    logic valid_stage2;
    logic valid_stage3;
    logic signed [TWIDDLE_W-1:0] reg_w_real;
    logic signed [TWIDDLE_W-1:0] reg_w_imag;
    logic signed [SAMPLE_W-1:0]reg_b_real;
    logic signed [SAMPLE_W-1:0]reg_b_imag;
    logic signed [SAMPLE_W+TWIDDLE_W-1:0] p1;
    logic signed [SAMPLE_W+TWIDDLE_W-1:0]p2;
    logic signed [SAMPLE_W+TWIDDLE_W-1:0]p3;
    logic signed [SAMPLE_W+TWIDDLE_W-1:0] p4;
    logic signed [SAMPLE_W+TWIDDLE_W:0] rounded_real;
    logic signed [SAMPLE_W+TWIDDLE_W:0] rounded_imag;
    logic signed [SAMPLE_W+TWIDDLE_W:0] reg_t_real;
    logic signed [SAMPLE_W+TWIDDLE_W:0] reg_t_imag;

    always_comb begin
    rounded_real = reg_t_real[SAMPLE_W+TWIDDLE_W]
        ? -(((-reg_t_real) + (1 <<< (FRAC_W-1))) >>> FRAC_W)
        :  (( reg_t_real  + (1 <<< (FRAC_W-1))) >>> FRAC_W);

    rounded_imag = reg_t_imag[SAMPLE_W+TWIDDLE_W]
        ? -(((-reg_t_imag) + (1 <<< (FRAC_W-1))) >>> FRAC_W)
        :  (( reg_t_imag  + (1 <<< (FRAC_W-1))) >>> FRAC_W);
    end





    always_ff @( posedge clk ) begin

        if(reset) begin
            valid_out <= 1'b0;
            t_real<= '0;
            t_imag<= '0;
            valid_stage1<=1'b0;
            valid_stage2<=1'b0;
            valid_stage3<=1'b0;

        end

        else begin
            reg_b_real <= b_real;
            reg_b_imag <= b_imag;
            reg_w_real <= w_real;
            reg_w_imag <= w_imag;
            p1 <= reg_b_real * reg_w_real;
            p2 <= reg_b_imag * reg_w_imag;
            p3 <= reg_b_real * reg_w_imag;
            p4 <= reg_b_imag * reg_w_real;
            reg_t_real <=$signed({p1[SAMPLE_W+TWIDDLE_W-1], p1})- $signed({p2[SAMPLE_W+TWIDDLE_W-1], p2});

            reg_t_imag <= $signed({p3[SAMPLE_W+TWIDDLE_W-1], p3})+ $signed({p4[SAMPLE_W+TWIDDLE_W-1], p4});
            


            if (rounded_real > ((1 <<< (SAMPLE_W-1)) - 1))
                 t_real <= {1'b0, {(SAMPLE_W-1){1'b1}}};
            else if (rounded_real < -(1 <<< (SAMPLE_W-1)))
                t_real <= {1'b1, {(SAMPLE_W-1){1'b0}}};
            else
                t_real <= rounded_real[SAMPLE_W-1:0];

            if (rounded_imag > ((1 <<< (SAMPLE_W-1)) - 1))
                t_imag <= {1'b0, {(SAMPLE_W-1){1'b1}}};
            else if (rounded_imag < -(1 <<< (SAMPLE_W-1)))
                t_imag <= {1'b1, {(SAMPLE_W-1){1'b0}}};
            else
                t_imag <= rounded_imag[SAMPLE_W-1:0];







            valid_stage1 <= valid_in;
            valid_stage2 <= valid_stage1;
            valid_stage3 <= valid_stage2;
            valid_out    <= valid_stage3;

        end 

    end


        

        
    
endmodule
