`timescale 1ns / 1ps

module edge_detector(
    input logic clk,
    input logic reset,
    input logic signal_in,
    output logic pulse
    );
    
    logic previous_signal;
    
    always_ff @(posedge clk) begin
        if(reset) begin
            previous_signal <= 1'b0;
        end else begin
            previous_signal <= signal_in;
        end
    end
    
    assign pulse = !previous_signal && signal_in;
    
endmodule
