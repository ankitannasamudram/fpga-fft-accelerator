`timescale 1ns/1ps

module uart_tx #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] tx_data,
    input  logic       tx_valid,

    output logic       uart_tx,
    output logic       tx_busy
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] tx_shift;


    always_ff @(posedge clk) begin

        if (reset) begin

            state     <= IDLE;
            clk_count <= '0;
            bit_index <= '0;
            tx_shift  <= '0;

        end

        else begin

            case (state)

                IDLE: begin

                    clk_count <= '0;
                    bit_index <= '0;

                    // save the byte when a new transmission is requested
                    if (tx_valid) begin
                        tx_shift <= tx_data;
                        state <= START;
                    end

                end


                START: begin

                    // hold the start bit low for one full UART bit time
                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= '0;
                        state <= DATA;

                    end

                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                DATA: begin

                    // hold each data bit for one full UART bit time
                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= '0;

                        // after bit 7 move to the stop bit
                        if (bit_index == 3'd7) begin

                            bit_index <= '0;
                            state <= STOP;

                        end

                        else begin

                            bit_index <= bit_index + 1'b1;

                        end

                    end

                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                STOP: begin

                    // hold the stop bit high for one full UART bit time
                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= '0;
                        state <= IDLE;

                    end

                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end


    // drive the UART line based on the current state
    always_comb begin

        case (state)

            IDLE:
                uart_tx = 1'b1;

            START:
                uart_tx = 1'b0;

            DATA:
                uart_tx = tx_shift[bit_index];

            STOP:
                uart_tx = 1'b1;

            default:
                uart_tx = 1'b1;

        endcase

    end


    // transmitter is busy whenever it is not in IDLE
    assign tx_busy = (state != IDLE);


endmodule