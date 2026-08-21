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
        WAIT_BUSY
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

            // tx_valid is only pulsed for one clock when giving a byte to uart_tx
            tx_valid <= 1'b0;

            case (state)

                IDLE: begin

                    byte_count <= 3'd0;

                    // accept a new FFT bin when both valid and ready are high
                    if (fft_valid && fft_ready) begin

                        // sign extend the 22 bit FFT values to 24 bits
                        real_buffer <= {{2{fft_real[21]}}, fft_real};
                        imag_buffer <= {{2{fft_imag[21]}}, fft_imag};

                        state <= SEND;

                    end

                end


                SEND: begin

                    // only send a new byte when uart_tx is not busy
                    if (!tx_busy) begin

                        case (byte_count)

                            // send real value low byte
                            3'd0:
                                tx_data <= real_buffer[7:0];

                            // send real value middle byte
                            3'd1:
                                tx_data <= real_buffer[15:8];

                            // send real value high byte
                            3'd2:
                                tx_data <= real_buffer[23:16];

                            // send imaginary value low byte
                            3'd3:
                                tx_data <= imag_buffer[7:0];

                            // send imaginary value middle byte
                            3'd4:
                                tx_data <= imag_buffer[15:8];

                            // send imaginary value high byte
                            3'd5:
                                tx_data <= imag_buffer[23:16];

                            default:
                                tx_data <= 8'h00;

                        endcase

                        // tell uart_tx that tx_data contains a new byte
                        tx_valid <= 1'b1;

                        state <= WAIT_BUSY;

                    end

                end


                WAIT_BUSY: begin

                    // wait until uart_tx sees tx_valid and becomes busy
                    if (tx_busy) begin

                        // after byte 5 the complete FFT bin has been sent
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


    // only accept a new FFT output when the serializer is completely free
    assign fft_ready = (state == IDLE);


endmodule