module fft_controller (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic input_valid,
    input  logic output_ready,
    input  logic butterfly_valid_out,
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
    // TODO: IDLE, LOAD, COMPUTE, DRAIN, OUTPUT.
endmodule
