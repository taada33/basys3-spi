`timescale 1ns / 1ps

module active_low_encoder #(
    parameter int WIDTH = 4
)(
    input logic [WIDTH-1:0] input_n,
    
    output logic [((WIDTH <= 1) ? 1 : $clog2(WIDTH))-1:0] encoded,
    output logic valid
    );
    
    always_comb begin
        encoded = '0;
        for(int j = 0; j < $clog2(WIDTH); j++) begin
            for(int i = 0; i < WIDTH; i++) begin
                if(i[j] == 1'b1) begin
                    encoded[j] = encoded[j] | ~input_n[i];
                end
            end
        end
    end
    
    assign valid = (~input_n != '0) && ((~input_n & (~input_n - WIDTH'(1))) == '0);
    
    
endmodule
