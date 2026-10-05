`timescale 1ns / 1ps

module debouncer #(
    parameter int DEBOUNCE_FREQ = 125,
    parameter int CLK_FREQ = 100_000_000
    )(
    input logic clk,
    input logic reset,
    input logic signal_in,
    output logic signal_out
    );
    
    //8 ms debounce period
    localparam int DEBOUNCE_CYCLES = CLK_FREQ / DEBOUNCE_FREQ;
    
    logic [$clog2(DEBOUNCE_CYCLES)-1:0] counter;
    
    always_ff @ (posedge clk) begin
        if(reset) begin
            counter <= 0;
            signal_out <= 0;
        end else if(signal_in == signal_out) begin
            counter <= 0;
        end else if (counter == DEBOUNCE_CYCLES-1) begin
            counter <= 0;
            signal_out <= signal_in;
        end else begin
            counter <= counter + 1;
        end
    end
    
    
    
endmodule
