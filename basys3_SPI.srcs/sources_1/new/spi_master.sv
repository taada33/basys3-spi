`timescale 1ns / 1ps

module spi_master #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_SLAVES = 1,
    parameter int CLK_FREQ = 100_000_000,
    parameter int SPI_FREQ = 10_000_000,
    parameter int CPOL = 0,
    parameter int CPHA = 0
)(
    //AXI4-Stream interfaces
    axis_if.slave  s_axis_tx,
    axis_if.master m_axis_rx,
    
    //SPI signals
    output logic [NUM_SLAVES-1:0] cs_n,
    input logic miso,
    output logic sclk,
    output logic mosi
    );
    
    logic clk;
    logic reset;
    
    logic [DATA_WIDTH-1:0] rx_data;
    logic [((NUM_SLAVES <= 1) ? 1 : $clog2(NUM_SLAVES))-1:0] slave_select;
    
    logic last;
    logic tx_handshake;
    
    localparam int CYCLES_SPI = CLK_FREQ / SPI_FREQ;
    localparam int HALF_CYCLES = CYCLES_SPI/2;
    localparam int COUNTER_WIDTH = HALF_CYCLES <= 1 ? 1 : $clog2(HALF_CYCLES);
    logic [((DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH))-1:0] data_counter;
    
    
    logic [COUNTER_WIDTH-1:0] counter_spi;
    logic [COUNTER_WIDTH-1:0] counter_assert;
    logic [COUNTER_WIDTH-1:0] counter_deassert;
    
    logic [DATA_WIDTH-1:0] mosi_data;
    
    typedef enum logic [2:0] {
        IDLE,
        ASSERT_CS_N,
        DATA,
        WAIT_DATA,
        DEASSERT_CS_N
    } state_t;  
    state_t state;
    
    //global signals
    assign clk = m_axis_rx.ACLK;
    assign reset = ~m_axis_rx.ARESETn;
    
    //Slave signals (CONTROLLER to SPI MASTER)
    assign s_axis_tx.TREADY = ((state == IDLE || state == WAIT_DATA) && ~(m_axis_rx.TVALID && ~m_axis_rx.TREADY));
    assign tx_handshake = s_axis_tx.TVALID && s_axis_tx.TREADY;
    
    //Master signals (SPI MASTER to CONTROLLER)
    assign m_axis_rx.TDATA = rx_data;
    //unused signals
    assign m_axis_rx.TLAST = 1'b0;
    assign m_axis_rx.TDEST = '0;

    //TVALID control block
    always_ff @(posedge clk) begin
        if(reset) begin
            m_axis_rx.TVALID <= 1'b0;
            //TVALID 1'b1 conditions
        end else if((state == DATA) //state is DATA
         && (counter_spi == HALF_CYCLES-1) //sclk edge
         && (data_counter == DATA_WIDTH-1) //last data bit
         && (CPHA ? sclk != CPOL // CPHA = 1 --> trailing sampling edge 
          : sclk == CPOL) // CPHA = 0 --> leading sampling edge
          ) begin
            m_axis_rx.TVALID <= 1'b1;
        end else if(m_axis_rx.TVALID && m_axis_rx.TREADY) begin
            m_axis_rx.TVALID <= 1'b0;
        end
    end
    

    //counters block
    always_ff @(posedge clk) begin
        if(reset) begin
            counter_spi <= 0;
            counter_assert <= 0;
            counter_deassert <= 0;
            sclk <= CPOL;
        end else if(state == ASSERT_CS_N) begin
            if(counter_assert == HALF_CYCLES-1) begin
                counter_assert <= 0;
            end else begin
                counter_assert <= counter_assert + 1;
            end
        end else if(state == DEASSERT_CS_N) begin
            if(counter_deassert == HALF_CYCLES-1) begin
                counter_deassert <= 0;
            end else begin
                counter_deassert <= counter_deassert + 1;
            end
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
            mosi <= 1'b0;
            rx_data <= 0;
            mosi_data <= 0;
            data_counter <= 0; 
            last <= 1'b0;
            slave_select <= '0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= '1;
                    if(tx_handshake == 1'b1) begin
                        state <= ASSERT_CS_N;
//                        mosi_data <= tx_data;
                        mosi_data <= s_axis_tx.TDATA;
                        last <= s_axis_tx.TLAST;
                        slave_select <= s_axis_tx.TDEST;
                    end
                end
                ASSERT_CS_N: begin
                    cs_n <= ~(NUM_SLAVES'(1) << slave_select);
                    data_counter <= 0;
                    //chip select setup time tCSS
                    if(counter_assert == HALF_CYCLES-1) begin
                        state <= DATA;
                    end
                    //preload mosi line if clock phase is 0
                    if(!CPHA && counter_assert == 0) begin
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
                            if(last == 1'b1) begin 
                                state <= DEASSERT_CS_N;
                            end else begin
                                state <= WAIT_DATA;
                                data_counter <= 0;
                            end
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
                            if(last == 1'b1) begin
                                state <= DEASSERT_CS_N;
                            end else begin
                                data_counter <= 0;
                                state <= WAIT_DATA;
                            end
                          end
                        //leading edge sample
                        end else if(sclk == CPOL && counter_spi == HALF_CYCLES-1) begin
                          rx_data <= (rx_data << 1) | miso;
                        end
                    end
                end
                WAIT_DATA: begin
                    if(tx_handshake == 1'b1) begin
                        state <= DATA;
                        mosi_data <= s_axis_tx.TDATA;
                        last <= s_axis_tx.TLAST;
                        if(!CPHA) begin
                            mosi <= s_axis_tx.TDATA[DATA_WIDTH-1];
                            mosi_data <= s_axis_tx.TDATA << 1;
                        end
                    end
                end
                DEASSERT_CS_N: begin
                    data_counter <= 0;
                    //chip-select hold time tCSH
                    if(counter_deassert == HALF_CYCLES-1) begin
                        state <= IDLE;
                        cs_n <= '1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
