`timescale 1ns / 1ps

module button_conditioner #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int DEBOUNCE_FREQ = 125
)(
    input logic clk,
    input logic reset,
    input logic signal_in,
    
    output logic signal_out
    );
    
    logic signal_sync;
    logic signal_debounced;
   
   synchronizer synchronizer_inst (
        .clk(clk),
        .reset(reset),
        .signal_in(signal_in),
        .signal_out(signal_sync)
   );
   
   debouncer #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_FREQ(DEBOUNCE_FREQ)
   ) debouncer_inst (
        .clk(clk),
        .reset(reset),
        .signal_in(signal_sync),
        .signal_out(signal_debounced)
   );
   
   edge_detector edge_detector_inst (
        .clk(clk),
        .reset(reset),
        .signal_in(signal_debounced),
        .pulse(signal_out)
   );
   
endmodule
