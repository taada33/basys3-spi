`timescale 1ns / 1ps

module synchronizer(
    input logic clk,
    input logic reset,
    input logic signal_in,
    output logic signal_out
    );
    
    logic ff1, ff2;
    
    always_ff @(posedge clk) begin
        if(reset) begin
            ff1 <= 0;
            ff2 <= 0;
        end else begin
            ff1 <= signal_in;
            ff2 <= ff1;
        end
    end
    
    assign signal_out = ff2;
    
    
endmodule
