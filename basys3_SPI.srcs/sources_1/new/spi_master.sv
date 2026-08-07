`timescale 1ns / 1ps

module spi_master #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_SLAVES = 1,
    parameter int CLK_FREQ = 100_000_000,
    parameter int SPI_FREQ = 10_000_000,
    parameter int CPOL = 0,
    parameter int CPHA = 0
)(
    input logic clk,
    input logic reset,
    
    input logic [DATA_WIDTH-1:0] tx_data,
    output logic [DATA_WIDTH-1:0] rx_data,
    
    input logic [((NUM_SLAVES <= 1) ? 1 : $clog2(NUM_SLAVES))-1:0] slave_select,
    output logic [NUM_SLAVES-1:0] cs_n,
    
    input logic tx_start,
    output logic busy,
    output logic done,
    
    input logic miso,
    output logic sclk,
    output logic mosi
    );
    
    localparam int CYCLES_SPI = CLK_FREQ / SPI_FREQ;
    localparam int HALF_CYCLES = CYCLES_SPI/2;
    localparam int COUNTER_WIDTH = HALF_CYCLES <= 1 ? 1 : $clog2(HALF_CYCLES);
    logic [((DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH))-1:0] data_counter;
    logic [COUNTER_WIDTH-1:0] counter_spi;
    logic [DATA_WIDTH-1:0] mosi_data;
    
    typedef enum logic [1:0] {
        IDLE,
        ASSERT_CS_N,
        DATA,
        DEASSERT_CS_N
    } state_t;  
    state_t state;
    
    
    always_ff @(posedge clk) begin
        if(reset) begin
            counter_spi <= 0;
            sclk <= CPOL;
        end else if(state == DATA) begin
            if(counter_spi == HALF_CYCLES-1) begin
                counter_spi <= 0;
                sclk <= ~sclk;
            end else begin
                counter_spi <= counter_spi + 1;
            end
        end else begin
            sclk <= CPOL;
            counter_spi <= 0;
        end
    end
    
    //fsm
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= IDLE;
            cs_n <= '1;
            busy <= 1'b0;
            done <= 1'b0;
            mosi <= 1'b0;
            rx_data <= 0;
            mosi_data <= 0;
            data_counter <= 0;      
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= '1;
                    busy <= 1'b0;
                    done <= 1'b0; 
                    if(tx_start == 1'b1) begin
                        state <= ASSERT_CS_N;
                        mosi_data <= tx_data;
                    end
                end
                ASSERT_CS_N: begin
                    busy <= 1'b1;
                    cs_n <= ~(NUM_SLAVES'(1) << slave_select);
                    data_counter <= 0;
                    state <= DATA;
                    //preload mosi line if clock phase is 0
                    if(!CPHA) begin
                        mosi <= mosi_data[DATA_WIDTH-1];
                        mosi_data <= mosi_data << 1;
                    end
                end
                DATA: begin
                    if(CPHA) begin
                        //leading edge shift
                        if(sclk == CPOL && counter_spi == HALF_CYCLES-1) begin
                          mosi <= mosi_data[DATA_WIDTH-1];
                          mosi_data <= mosi_data << 1;
                        //trailing edge sample
                        end else if(sclk != CPOL && counter_spi == HALF_CYCLES-1) begin
                          rx_data <= (rx_data << 1) | miso;
                          if(data_counter == DATA_WIDTH-1) begin
                            state <= DEASSERT_CS_N;
                          end else begin
                            data_counter <= data_counter + 1;
                          end 
                        end
                    end else begin
                        //trailing edge shift
                        if(sclk != CPOL && counter_spi == HALF_CYCLES-1) begin
                          if(data_counter != DATA_WIDTH-1) begin
                            mosi <= mosi_data[DATA_WIDTH-1];
                            mosi_data <= mosi_data << 1;
                            data_counter <= data_counter + 1;
                          end else begin
                            state <= DEASSERT_CS_N;
                          end
                        //leading edge sample
                        end else if(sclk == CPOL && counter_spi == HALF_CYCLES-1) begin
                          rx_data <= (rx_data << 1) | miso;
                        end
                    end
                end
                DEASSERT_CS_N: begin
                    cs_n <= '1;
                    data_counter <= 0;
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
