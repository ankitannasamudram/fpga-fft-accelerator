`timescale 1ns/1ps

module uart_rx #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       uart_rx,

    output logic [7:0] rx_data,
    output logic       rx_valid
);

localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state;


logic rx_ff1;
logic rx_ff2;

logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
logic [2:0] bit_index;


always_ff @(posedge clk) begin
    
    if (reset) begin
        state     <= IDLE;
        clk_count <= '0;
        bit_index <= '0;
        rx_data   <= '0;
        rx_valid  <= 1'b0;
    end
    else begin
        rx_valid <= 1'b0;

        case (state)

            IDLE: begin
                clk_count<= '0;
                if (!rx_ff2)
                    state <=START;

            end

            START: begin
                if (clk_count == (CLKS_PER_BIT /2)-1) begin
                    if(!rx_ff2) begin 
                        clk_count <='0;
                        bit_index <= '0;
                        state <= DATA;
                    end
                    else begin 
                        clk_count <='0;
                        state<= IDLE;
                    end
                end
                else 
                    clk_count <= clk_count +1;
                    

            end

            DATA: begin
                if (clk_count == CLKS_PER_BIT -1) begin
                    rx_data[bit_index] <= rx_ff2;
                    clk_count <= '0;
                    if (bit_index ==7) 
                        state <= STOP;
                    else 
                        bit_index<= bit_index +1;
                
                end
                else 
                    clk_count <= clk_count +1;
            end

            STOP: begin
                if (clk_count == CLKS_PER_BIT -1) begin
                    if (rx_ff2)
                        rx_valid <= 1'b1;

                    clk_count<='0;
                    state <= IDLE;
                end

                else 
                    clk_count<=clk_count+1;

            end

            default: begin
                    state     <= IDLE;
                    clk_count <= '0;
                    bit_index <= '0;
                end



        endcase
    end
end


always_ff @(posedge clk) begin
    if (reset) begin
        rx_ff1 <= 1'b1;
        rx_ff2 <= 1'b1;
    end

    else  begin
        rx_ff1 <= uart_rx;
        rx_ff2 <= rx_ff1;
    end
end

endmodule