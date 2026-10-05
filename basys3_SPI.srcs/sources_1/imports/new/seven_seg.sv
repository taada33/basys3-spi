`timescale 1ns / 1ps

module seven_seg #(
    parameter int REFRESH_HZ = 2000,
    parameter int CLK_FREQ = 100_000_000
    )(
    input logic clk,
    input logic reset,
    input logic [7:0] left_data,
    input logic [7:0] right_data,
    output logic [6:0] seg,
    output logic [3:0] an
    );
    
    localparam int REFRESH_CYCLES = CLK_FREQ / REFRESH_HZ;
    
    logic [$clog2(REFRESH_CYCLES)-1:0] counter;
    logic [3:0] digit;
    
    
    always_ff @ (posedge clk) begin
        if(reset) begin
            an <= 4'b1110;
            counter <= 0;
        end else if(counter == REFRESH_CYCLES-1) begin
            counter <= 0;
            an <= {an[2:0], an[3]};
        end else begin
            counter <= counter + 1;
        end
    end
    
    always_comb begin
       if(!an[0])
            digit = right_data[3:0];
       else if(!an[1])
            digit = right_data[7:4];
       else if(!an[2])
            digit = left_data[3:0];
       else
            digit = left_data[7:4];
                     
        case (digit)
            4'h0: seg = 7'b0000001;
            4'h1: seg = 7'b1001111;
            4'h2: seg = 7'b0010010;
            4'h3: seg = 7'b0000110;
            4'h4: seg = 7'b1001100;
            4'h5: seg = 7'b0100100;
            4'h6: seg = 7'b0100000;
            4'h7: seg = 7'b0001111;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0000100;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b1100000;
            4'hC: seg = 7'b0110001;
            4'hD: seg = 7'b1000010;
            4'hE: seg = 7'b0110000;
            4'hF: seg = 7'b0111000;
            default: seg = 7'b1111111;
        endcase 
    end
    
endmodule
