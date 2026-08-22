`timescale 1ns / 1ps

module spi_slave#(
    parameter int DATA_WIDTH = 8,
    parameter bit CPOL = 0,
    parameter bit CPHA = 0
)(  
    input logic sclk,
    input logic reset,
    input logic mosi,
    input logic cs_n,
    input logic [DATA_WIDTH-1:0] tx_data,
    
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic miso,
    output logic rx_valid
    );
    
    localparam int BIT_COUNTER_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    
    logic [DATA_WIDTH-1:0] rx = '0;
    logic [DATA_WIDTH-1:0] tx = '0;
    logic [BIT_COUNTER_WIDTH-1:0] bit_counter = '0;


    generate
        case({CPOL,CPHA})
            2'b00, 2'b11: begin : gen_mode0
                //sample
                always @(posedge sclk or posedge cs_n or posedge reset) begin
                    if(reset) begin
                        bit_counter <= 0;
                        rx <= '0;
                        rx_data <= '0;
                        rx_valid <= 1'b0;
                    end else if(cs_n) begin
                        bit_counter <= 0;
                        rx <= '0;
                        rx_valid <= 1'b0;
                    end else begin
                        rx_valid <= 1'b0;
                        rx <= {rx[DATA_WIDTH-2:0],mosi};
                        bit_counter <= bit_counter + 1;
                        if(bit_counter == DATA_WIDTH-1) begin
                            bit_counter <= 0;
                            rx_data <= {rx[DATA_WIDTH-2:0],mosi};
                            rx_valid <= 1'b1;
                        end
                    end
                end
                
                
                always @ (negedge sclk or cs_n or posedge reset) begin
                    if(reset || cs_n) begin
                        tx <= '0;
                    end else if(!cs_n && !CPHA && bit_counter == 0) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                    end else if(!cs_n && CPHA && bit_counter == 0 && sclk == CPOL) begin
                        tx <= tx_data;
                    end else if(!cs_n && CPHA && rx_valid) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                    end else begin
                        miso <= tx[DATA_WIDTH-1];
                        tx <= tx << 1;
                    end
                end
            end
            2'b01, 2'b10: begin : gen_mode1
                //sample
                always @(negedge sclk or posedge cs_n or posedge reset) begin
                    if(reset) begin
                        bit_counter <= 0;
                        rx <= '0;
                        rx_data <= '0;
                        rx_valid <= 1'b0;
                    end else if(cs_n) begin
                        bit_counter <= 0;
                        rx <= '0;
                        rx_valid <= 1'b0;
                    end else begin
                        rx_valid <= 1'b0;
                        rx <= {rx[DATA_WIDTH-2:0],mosi};
                        bit_counter <= bit_counter + 1;
                        
                        if(bit_counter == DATA_WIDTH-1) begin
                            bit_counter <= 0;
                            rx_data <= {rx[DATA_WIDTH-2:0],mosi};
                            rx_valid <= 1'b1;
                        end
                    end 
                end
                
                always @ (posedge sclk or cs_n or posedge reset) begin
                    if(reset || cs_n) begin
                        tx <= '0;
                        miso <= 1'b0;
                    end else if(!cs_n && !CPHA && bit_counter == 0) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                    end else if(!cs_n && CPHA && bit_counter == 0 && sclk == CPOL) begin
                        tx <= tx_data;
                    end else if(!cs_n && CPHA && rx_valid) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                    end else begin
                        miso <= tx[DATA_WIDTH-1];
                        tx <= tx << 1;
                    end
                end
            end
        endcase
    endgenerate
    
endmodule
