`timescale 1ns/1ps

module uart_sample_assembler (

input  logic       clk,
input  logic       reset,

input  logic [7:0] rx_data,
input  logic       rx_valid,

output logic signed [15:0] sample_real,
output logic signed [15:0] sample_imag
output logic               sample_valid,
);

logic [7:0] real_low;
logic [7:0] real_high;

logic [7:0] imag_low;
logic [7:0] imag_high;


logic [1:0] byte_count;

always_ff @(posedge clk) begin
    if(reset) begin

        real_low <='0;
        real_high <= '0;
        imag_low <='0;
        imag_high <= '0;
        byte_count  <= '0;
        sample_real <= '0;
        sample_imag <= '0;
        sample_valid <= 1'b0;


    end

    else begin
        

        if (rx_valid) begin
            case( byte_count) 

                2'd0 : real_low <= rx_data;
                        byte_count<= byte_count+1; 
                2'd1 :  real_high <= rx_data;
                        byte_count<= byte_count+1;
                2'd2 : imag_low <= rx_data;
                        byte_count<= byte_count+1;
                2'd3 : imag_high <= rx_data;
                        byte_count<= 2'd0;
                        sample_valid <=1'b1;
                        sample_real <= {real_high, real_low};
                        sample_imag <= {rx_data, imag_low}; 
                        // included here and not in an assign statement because 
                        //we do not want errors with sample-valid going high while sample_imag reflects the old value during that clock edge 

    end

    
end









endmodule

