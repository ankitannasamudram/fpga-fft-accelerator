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
    
    output logic [5:0] write_addr_a,
    output logic [5:0] write_addr_b,
    output logic       write_enable,
    output logic butterfly_valid_in,
    output logic butterfly_last_in
);

logic [5:0] write_addr_a_pipe [0:5];
logic [5:0] write_addr_b_pipe [0:5];

logic       valid_pipe        [0:5];
logic butterfly_valid_delay;
logic butterfly_last_delay;

typedef enum logic [2:0] {
    IDLE,
    LOAD,
    ISSUE,
    WAIT_STAGE,
    OUTPUT,
    DONE
} state_t;

state_t state, next_state;

always_ff @(posedge clk) begin
    if (reset)
        state<= IDLE;
    else
        state<=next_state;
end

always_comb begin
    next_state = state;
    case(state)
        // waiting for a new FFT operation to begin 
        IDLE : if(start)
                    next_state= LOAD;
                else
                    next_state=IDLE;
        // ACcept and store 64 input samples into the input memory bank
        LOAD:  if (input_ready && input_valid && load_count==6'd63) 
                    next_state = ISSUE;
                else 
                    next_state = LOAD;
        // this state to issue 32 butterlfy operations for the current FFT stage
        ISSUE : if (issue_read && butterfly_count==5'd31)
                    next_state = WAIT_STAGE;
                else 
                    next_state = ISSUE;

        // waiting for the final butterfly result of the current stage
        WAIT_STAGE: if(butterfly_last_out)
                        if( stage_count ==5)
                            next_state = OUTPUT;
                        else 
                            next_state =ISSUE;
                    else
                        next_state = WAIT_STAGE;
        // send the 64 completed FFT samples to the output interface
        OUTPUT: if (output_valid &&output_ready && output_count ==63)
                    next_state= DONE;
                else
                    next_state = OUTPUT;
        // this is to make debugging easier, shows that the FFT fram is ocmplete for on cycle
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase

    
end



always_ff @(posedge clk) begin 

    if (reset) begin
        valid_pipe[0] <= 1'b0;
        valid_pipe[1] <= 1'b0;
        valid_pipe[2] <= 1'b0;
        valid_pipe[3] <= 1'b0;
        valid_pipe[4] <= 1'b0;
        valid_pipe[5] <= 1'b0;
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

end


always_ff @(posedge clk) begin
     if (reset) begin
        load_count       <= 6'd0;
        output_count     <= 6'd0;
        butterfly_count  <= 5'd0;
        stage_count      <= 3'd0;
        source_bank      <= 1'b0;
        
     end

     else begin
       case (state)

       IDLE : begin
              load_count<='0;
              output_count<='0;
              stage_count<='0;
              butterfly_count<='0;
              source_bank<='0;
       end
             
       LOAD: 
            if (input_ready && input_valid)
                if (load_count == 6'd63)
                    load_count<= 6'b0;
                else
                    load_count <= load_count +1'b1;
            else 
                load_count <= load_count;
       ISSUE: 
              if (butterfly_count!=5'd31) begin
                butterfly_count<= butterfly_count +1'd1;
                
              end

              


       WAIT_STAGE: begin
                    

                    if (butterfly_last_out) begin
                        source_bank <= ~source_bank; // this is the ping pong memeory aspect 
                        if (stage_count != 3'd5)  begin
                            stage_count <= stage_count + 3'd1;
                            butterfly_count <= 5'd0;
                            
                        end
                    end
                end

       OUTPUT: if (output_valid && output_ready)
                if(output_count == 6'd63) 
                    output_count<= 6'd0;
                else
                    output_count<= output_count +1'd1;
       DONE: begin //no registered updates

       end
                
        endcase

     end
end
    // The sample memory has a 1cycle synchronous read latency.
    // When we issue addresses in cycle N, the corresponding A/B sample data does not reach the butterfly until cycle N+1.
    // Delay valid and last by one clock so these control signals stay aligned with the memory data entering the butterfly.

    always_ff @(posedge clk) begin
        if (reset) begin
            butterfly_valid_delay <= 1'b0;
            butterfly_last_delay  <= 1'b0;
        end
        else begin
            butterfly_valid_delay <= issue_read;
            butterfly_last_delay  <= issue_read &&
                                    (butterfly_count == 5'd31);
        end
    end






// these are declared outside because we need these updated as soon as possible
//inside the always ff block these are sequentiial and only apply once every clock edge and this can an extra issuence in butterflies.
assign input_ready  = (state == LOAD);
assign output_valid = (state == OUTPUT);
assign done         = (state == DONE);
assign busy         = (state != IDLE) && (state != DONE);

assign issue_read = (state == ISSUE);

assign butterfly_valid_in = butterfly_valid_delay;
assign butterfly_last_in  = butterfly_last_delay;

assign write_addr_a = write_addr_a_pipe[5];
assign write_addr_b = write_addr_b_pipe[5];
assign write_enable = butterfly_valid_out;


    
    
endmodule
