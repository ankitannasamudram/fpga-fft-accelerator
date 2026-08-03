module bit_reverse #(
    parameter int WIDTH = fft_pkg::ADDR_W
) (
    input  logic [WIDTH-1:0] index_in,
    output logic [WIDTH-1:0] index_out
);
    //Simple for loop for bit reversal for variable WIDTH
   

    integer i;


always_comb begin
    for (i= 0; i<WIDTH; i=i+1) begin 
     index_out[i] = index_in[(WIDTH-1)-i];


    end 

    end

endmodule
