module fft_top (
    input logic clk,
    input logic reset,
    input logic start,
    input logic input_valid,
    output logic input_ready,
    input logic signed [fft_pkg::INPUT_W-1:0] input_real,
    input logic signed [fft_pkg::INPUT_W-1:0] input_imag,
    output logic busy,
    output logic done,
    output logic output_valid,
    input logic output_ready,
    output logic [fft_pkg::ADDR_W-1:0] output_bin,
    output logic signed [fft_pkg::SAMPLE_W-1:0] output_real,
    output logic signed [fft_pkg::SAMPLE_W-1:0] output_imag
);


    logic [5:0] load_addr_bitrev;
    logic [2:0] stage_count;
    logic [4:0] butterfly_count;

    logic [5:0] load_count;
    logic [5:0] output_count;

    logic [5:0] addr_a;
    logic [5:0] addr_b;
    logic [4:0] twiddle_addr;

    logic source_bank;
    logic issue_read;
    logic [5:0] write_addr_a;
    logic [5:0] write_addr_b;
    logic write_enable;
    logic butterfly_valid_in;
    logic butterfly_last_in;

    logic butterfly_valid_out;
    logic butterfly_last_out;

    logic mem0_a_we;
    logic [5:0] mem0_a_addr;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_a_wreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_a_wimag;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_a_rreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_a_rimag;

    logic mem0_b_we;
    logic [5:0] mem0_b_addr;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_b_wreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_b_wimag;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_b_rreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem0_b_rimag;

    logic mem1_a_we;
    logic [5:0] mem1_a_addr;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_a_wreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_a_wimag;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_a_rreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_a_rimag;

    logic mem1_b_we;
    logic [5:0] mem1_b_addr;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_b_wreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_b_wimag;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_b_rreal;
    logic signed [fft_pkg::SAMPLE_W-1:0] mem1_b_rimag;

    logic signed [fft_pkg::SAMPLE_W-1:0] butterfly_a_real;
    logic signed [fft_pkg::SAMPLE_W-1:0] butterfly_a_imag;
    logic signed [fft_pkg::SAMPLE_W-1:0] butterfly_b_real;
    logic signed [fft_pkg::SAMPLE_W-1:0] butterfly_b_imag;

    logic signed [fft_pkg::SAMPLE_W-1:0] y0_real;
    logic signed [fft_pkg::SAMPLE_W-1:0] y0_imag;
    logic signed [fft_pkg::SAMPLE_W-1:0] y1_real;
    logic signed [fft_pkg::SAMPLE_W-1:0] y1_imag;



    logic signed [fft_pkg::TWIDDLE_W-1:0] w_real;
    logic signed [fft_pkg::TWIDDLE_W-1:0] w_imag;

    logic [3:0] butterfly_last_out_pipe;

   

    logic controller_output_valid;

    logic output_valid_delay;
    logic [fft_pkg::ADDR_W-1:0] output_bin_delay;
    logic output_bank_delay;
    logic controller_output_ready;

    fft_address_gen addr_gen (.stage(stage_count),
        .butterfly_count(butterfly_count),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .twiddle_addr(twiddle_addr)
    );

    twiddle_rom tw_rom (
        .clk(clk),
        .addr(twiddle_addr),

        .w_real(w_real),
        .w_imag(w_imag)
    );

    fft_controller controller (.clk(clk),
        .reset(reset),
        .start(start),
        .input_valid(input_valid),
        .output_ready(controller_output_ready),
        .butterfly_valid_out(butterfly_valid_out),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .butterfly_last_out(butterfly_last_out),
        .input_ready(input_ready),
        .output_valid(controller_output_valid),
        .busy(busy),
        .done(done),
        .stage_count(stage_count),
        .butterfly_count(butterfly_count),
        .load_count(load_count),
        .output_count(output_count),
        .source_bank(source_bank),
        .issue_read(issue_read),
        
        .write_addr_a(write_addr_a),
        .write_addr_b(write_addr_b),
        .write_enable(write_enable),
        .butterfly_valid_in(butterfly_valid_in),
        .butterfly_last_in(butterfly_last_in)
      
        );

    fft_memory mem0 (.clk(clk),
    .port_a_we(mem0_a_we),
    .port_a_wreal(mem0_a_wreal),
    .port_a_addr(mem0_a_addr),
    .port_a_wimag(mem0_a_wimag),
    .port_a_rreal(mem0_a_rreal),
    .port_a_rimag(mem0_a_rimag),
    .port_b_we(mem0_b_we),
    .port_b_addr(mem0_b_addr),
    .port_b_rimag(mem0_b_rimag),
    .port_b_rreal(mem0_b_rreal),
    .port_b_wimag(mem0_b_wimag),
    .port_b_wreal(mem0_b_wreal)
    );

    
    fft_memory mem1 (.clk(clk),
    .port_a_we(mem1_a_we),
    .port_a_wreal(mem1_a_wreal),
    .port_a_addr(mem1_a_addr),
    .port_a_wimag(mem1_a_wimag),
    .port_a_rreal(mem1_a_rreal),
    .port_a_rimag(mem1_a_rimag),
    .port_b_we(mem1_b_we),
    .port_b_addr(mem1_b_addr),
    .port_b_rimag(mem1_b_rimag),
    .port_b_rreal(mem1_b_rreal),
    .port_b_wimag(mem1_b_wimag),
    .port_b_wreal(mem1_b_wreal)
    );


    fft_butterfly butterfly (.clk(clk),
    .reset(reset),
    .valid_in(butterfly_valid_in),
    .a_real(butterfly_a_real),
    .a_imag(butterfly_a_imag),
    .b_real(butterfly_b_real),
    .b_imag(butterfly_b_imag),
    .w_real(w_real),
    .w_imag(w_imag),
    .valid_out(butterfly_valid_out),
    .y0_real(y0_real),
    .y0_imag(y0_imag),
    .y1_imag(y1_imag),
    .y1_real(y1_real)
    );

    

   
    assign butterfly_a_real = source_bank ? mem1_a_rreal : mem0_a_rreal;
    assign butterfly_a_imag = source_bank ? mem1_a_rimag : mem0_a_rimag;

    assign butterfly_b_real = source_bank ? mem1_b_rreal : mem0_b_rreal;
    assign butterfly_b_imag = source_bank ? mem1_b_rimag : mem0_b_rimag;



    bit_reverse bit_reverse(.index_in(load_count),.index_out(load_addr_bitrev));


    always_comb begin

    
    // Defaults
    
    // Give every combinationally-driven memory signal a default
    // value so we do not infer latches.

    mem0_a_we    = 1'b0;
    mem0_b_we    = 1'b0;
    mem1_a_we    = 1'b0;
    mem1_b_we    = 1'b0;

    mem0_a_addr  = '0;
    mem0_b_addr  = '0;
    mem1_a_addr  = '0;
    mem1_b_addr  = '0;

    mem0_a_wreal = '0;
    mem0_a_wimag = '0;
    mem0_b_wreal = '0;
    mem0_b_wimag = '0;

    mem1_a_wreal = '0;
    mem1_a_wimag = '0;
    mem1_b_wreal = '0;
    mem1_b_wimag = '0;


    
    // LOAD
    
    // input_ready is high only while the controller is in LOAD.
    // Store incoming samples into mem0 using bit-reversed addresses.
    if (input_ready) begin

        mem0_a_we   = input_valid && input_ready;
         
        mem0_a_addr = load_addr_bitrev;

       
        mem0_a_wreal = input_real;
        mem0_a_wimag = input_imag;
        mem0_b_we = 1'b0;

    end


    
    // OUTPUT
    
    // output_valid is high while the controller is in OUTPUT.
    // The final FFT results are stored in source_bank.
    else if (controller_output_valid) begin

        if (source_bank) begin
            // Final data is in mem1
            mem1_a_addr = output_count;
        end
        else begin
            // Final data is in mem0
            mem0_a_addr = output_count;
        end

    end


    
    // FFT PROCESSING
    
    else begin

        // During FFT processing, source_bank selects which memory is read and which memory is written.
        //
        // The source bank has write enable = 0 because it is only supplying
        // the A and B samples for the current butterfly.
        //
        // The destination bank uses write_enable instead of always writing.
        // write_enable is asserted only when butterfly_valid_out is high,
        // meaning y0/y1 are valid and aligned with write_addr_a/write_addr_bThis

        if (source_bank) begin
            // mem1 = source/read bank
            // mem0 = destination/write bank

            mem1_a_we   = 1'b0;
            mem1_b_we   = 1'b0;

            mem1_a_addr = addr_a;
            mem1_b_addr = addr_b;

            mem0_a_we   = write_enable;
            mem0_b_we   = write_enable;

            mem0_a_addr = write_addr_a;
            mem0_b_addr = write_addr_b;

            mem0_a_wreal = y0_real;
            mem0_a_wimag = y0_imag;

            mem0_b_wreal = y1_real;
            mem0_b_wimag = y1_imag;

        end
        else begin
            // mem0 = source/read bank
            // mem1 = destination/write bank

            mem0_a_we   = 1'b0;
            mem0_b_we   = 1'b0;

            mem0_a_addr = addr_a;
            mem0_b_addr = addr_b;

            mem1_a_we   = write_enable;
            mem1_b_we   = write_enable;

            mem1_a_addr = write_addr_a;
            mem1_b_addr = write_addr_b;

            mem1_a_wreal = y0_real;
            mem1_a_wimag = y0_imag;

            mem1_b_wreal = y1_real;
            mem1_b_wimag = y1_imag;
        end

    end

end

    // fft_memory has a 1-cycle synchronous read latency.
    // Delay the output metadata by one cycle so output_bin/output_valid
    // line up with the actual FFT sample coming out of memory.
    always_ff @(posedge clk) begin
        if (reset) begin
            output_valid_delay <= 1'b0;
            output_bin_delay   <= '0;
            output_bank_delay  <= 1'b0;
        end
        else begin
            output_valid_delay <= controller_output_valid;

            if (controller_output_valid) begin
                output_bin_delay  <= output_count;
                output_bank_delay <= source_bank;
            end
        end
    end

    assign output_valid = output_valid_delay;
    assign output_bin   = output_bin_delay;

    // only let the controller advance when the delayed BRAM output
    // is actually valid and the downstream module is ready

    assign controller_output_ready = output_ready && output_valid_delay;

    

    assign output_real =
        output_bank_delay ? mem1_a_rreal : mem0_a_rreal;

    assign output_imag =
        output_bank_delay ? mem1_a_rimag : mem0_a_rimag;


    always_ff @(posedge clk) begin
        if (reset) begin
            butterfly_last_out_pipe <= '0;
            butterfly_last_out<=1'b0;
            
        end else begin
            butterfly_last_out_pipe[0] <= butterfly_last_in;
            butterfly_last_out_pipe[1] <= butterfly_last_out_pipe[0];
            butterfly_last_out_pipe[2] <= butterfly_last_out_pipe[1];
            butterfly_last_out_pipe[3] <= butterfly_last_out_pipe[2];
            butterfly_last_out<= butterfly_last_out_pipe[3];
        end
    end


   
  



endmodule
