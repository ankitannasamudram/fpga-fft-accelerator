`timescale 1ns/1ps
module fft_controller (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic input_valid,
    input  logic output_ready,
    input  logic butterfly_valid_out,
    input logic [5:0] addr_a,
    input logic [5:0] addr_b,
    input  logic butterfly_last_out,
    output logic input_ready,
    output logic output_valid,
    output logic busy,
    output logic done,
    output logic [2:0] stage_count,
    output logic [4:0] butterfly_count,
    output logic [5:0] load_count,
    output logic [5:0] output_count,
    output logic source_bank,
    output logic issue_read,
    output logic butterfly_last_in
);

logic [5:0] write_addr_a_pipe [0:5];
logic [5:0] write_addr_b_pipe [0:5];
logic       valid_pipe        [0:5];

always_ff @(posedge clk) begin 

    if (reset) begin
        valid_pipe[0] <= 1'b0;
        valid_pipe[1] <= 1'b0;
        valid_pipe[2] <= 1'b0;
        valid_pipe[3] <= 1'b0;
        valid_pipe[4] <= 1'b0;
    end
        




    else begin
        write_addr_a_pipe[0] <=addr_a;
        write_addr_a_pipe[1]<= write_addr_a_pipe[0];
        write_addr_a_pipe[2]<= write_addr_a_pipe[1];
        write_addr_a_pipe[3]<= write_addr_a_pipe[2];
        write_addr_a_pipe[4]<= write_addr_a_pipe[3];
        write_addr_a_pipe[5]<= write_addr_a_pipe[4];
        write_addr_b_pipe[0] <=addr_b;
        write_addr_b_pipe[1]<= write_addr_b_pipe[0];
        write_addr_b_pipe[2]<= write_addr_b_pipe[1];
        write_addr_b_pipe[3]<= write_addr_b_pipe[2];
        write_addr_b_pipe[4]<= write_addr_b_pipe[3];
        write_addr_b_pipe[5]<= write_addr_b_pipe[4];
        valid_pipe[0]<= issue_read;

        valid_pipe[1]<=valid_pipe[0];
        valid_pipe[2]<=valid_pipe[1];
        valid_pipe[3]<=valid_pipe[2];
        valid_pipe[4]<=valid_pipe[3];
        valid_pipe[5]<=valid_pipe[4];
    end 

    assign write_addr_a = write_addr_a_pipe[5];
    assign write_addr_b = write_addr_b_pipe[5];
    assign write_enable = butterfly_valid_out;


    
end
    
endmodule
