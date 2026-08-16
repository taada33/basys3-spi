`timescale 1ns / 1ps

module spi_slave#(
    parameter int DATA_WIDTH = 8,
    parameter bit CPOL = 0,
    parameter bit CPHA = 0
)(  
    input logic sclk,
    input logic reset, //don't need?
    input logic mosi,
    input logic cs_n,
    input logic [DATA_WIDTH-1:0] tx_data,
    
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic miso
    );
    
    localparam int BIT_COUNTER_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    
    logic [DATA_WIDTH-1:0] rx;
    logic [DATA_WIDTH-1:0] tx;

    logic [BIT_COUNTER_WIDTH-1:0] bit_counter;

    generate
        case({CPOL,CPHA})
            2'b00, 2'b11: begin : gen_mode0
                //sample
                always @(posedge sclk) begin
                    if(!cs_n) begin
                        rx <= {rx[DATA_WIDTH-2:0],mosi};
                        bit_counter <= bit_counter + 1;
                        
                        if(bit_counter == DATA_WIDTH-1) begin
                            bit_counter <= 0;
                            rx_data <= {rx[DATA_WIDTH-2:0],mosi};
                        end 
                    end
                end
                //shift
                always @(negedge sclk) begin
                    if(!cs_n)
                    tx <= tx << 1;
                end
            end
            2'b01, 2'b10: begin : gen_mode1
                //shift
                always @(posedge sclk) begin
                    if(!cs_n)
                    tx <= tx << 1;
                end
                //sample
                always @(negedge sclk) begin
                    if(!cs_n)
                    rx <= {rx[DATA_WIDTH-2:0],mosi};
                end
            end
        endcase
    endgenerate
    
    assign miso = tx[DATA_WIDTH-1];
    
    
    
    
    
endmodule
