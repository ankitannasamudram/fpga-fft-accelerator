`timescale 1ns/1ps

module uart_fft_serializer (
    input  logic clk,
    input  logic reset,

    input  logic signed [21:0] fft_real,
    input  logic signed [21:0] fft_imag,
    input  logic               fft_valid,
    output logic               fft_ready,

    output logic [7:0] tx_data,
    output logic       tx_valid,
    input  logic       tx_busy
);

    logic [23:0] real_buffer;
    logic [23:0] imag_buffer;

    logic [2:0] byte_count;

    typedef enum logic [1:0] {
        IDLE,
        SEND,
        WAIT_START,
        WAIT_DONE
    } state_t;

    state_t state;


    always_ff @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            real_buffer <= '0;
            imag_buffer <= '0;

            byte_count <= '0;

            tx_data <= '0;
            tx_valid <= 1'b0;

        end

        else begin

            // tx_valid is only pulsed for one clock
            tx_valid <= 1'b0;

            case (state)

                IDLE: begin

                    byte_count <= 3'd0;

                    // capture one FFT output when both sides agree
                    if (fft_valid && fft_ready) begin

                        // sign extend each 22 bit FFT value to 24 bits
                        real_buffer <= {{2{fft_real[21]}}, fft_real};
                        imag_buffer <= {{2{fft_imag[21]}}, fft_imag};

                        state <= SEND;

                    end

                end


                SEND: begin

                    // wait until uart_tx is free
                    if (!tx_busy) begin

                        case (byte_count)

                            3'd0:
                                tx_data <= real_buffer[7:0];

                            3'd1:
                                tx_data <= real_buffer[15:8];

                            3'd2:
                                tx_data <= real_buffer[23:16];

                            3'd3:
                                tx_data <= imag_buffer[7:0];

                            3'd4:
                                tx_data <= imag_buffer[15:8];

                            3'd5:
                                tx_data <= imag_buffer[23:16];

                            default:
                                tx_data <= 8'h00;

                        endcase

                        // request transmission of this byte
                        tx_valid <= 1'b1;

                        state <= WAIT_START;

                    end

                end


                WAIT_START: begin

                    // uart_tx has accepted the byte once busy goes high
                    if (tx_busy) begin
                        state <= WAIT_DONE;
                    end

                end


                WAIT_DONE: begin

                    // wait for the complete UART byte to finish
                    if (!tx_busy) begin

                        if (byte_count == 3'd5) begin

                            byte_count <= 3'd0;
                            state <= IDLE;

                        end

                        else begin

                            byte_count <= byte_count + 1'b1;
                            state <= SEND;

                        end

                    end

                end


                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end


    // a new FFT bin is accepted only when the serializer is completely free
    assign fft_ready = (state == IDLE);


endmodule