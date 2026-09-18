`timescale 1ns / 1ps

module spi_slave#(
    parameter int DATA_WIDTH = 8,
    parameter bit CPOL = 0,
    parameter bit CPHA = 0
)(  
    //AXI4-Stream interfaces
    axis_if.slave  s_axis_response,
    axis_if.master m_axis_request,
    
    
    //SPI signals
    input logic sclk,
    input logic reset,
    input logic mosi,
    input logic cs_n,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic miso,
    output logic rx_valid
    );
    
    //unused signal assignments
    assign m_axis_request.TLAST = 1'b0;
    assign m_axis_request.TDEST = '0;
    
    
    //Data signals
    logic [DATA_WIDTH-1:0] response_data; //ACLK domain
    logic [DATA_WIDTH-1:0] tx_data; //SCLK domain
    logic tx_data_consumed;
    
    //SPI internal
    localparam int BIT_COUNTER_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    logic [DATA_WIDTH-1:0] rx = '0;
    logic [DATA_WIDTH-1:0] tx = '0;
    logic [BIT_COUNTER_WIDTH-1:0] bit_counter = '0;
    
    //ACLK domain
    logic request_valid_meta;
    logic request_valid_sync;
    logic request_valid_sync_prev;
    
    //ACLK domain
    logic response_consumed_meta;
    logic response_consumed_sync;
    logic response_consumed_sync_prev;
    
    //SCLK domain
    logic response_consumed;
    
    logic response_ready_meta;
    logic response_ready_sync;
    logic response_ready_sync_prev;
    
    //Request CDC    
    always_ff @(posedge m_axis_request.ACLK) begin
        if(reset) begin
            m_axis_request.TVALID <= 1'b0;
            m_axis_request.TDATA <= '0;
            
            request_valid_meta <= 1'b0;
            request_valid_sync <= 1'b0;
            request_valid_sync_prev <= 1'b0;
        end else begin
            request_valid_meta <= rx_valid;
            request_valid_sync <= request_valid_meta;
            request_valid_sync_prev <= request_valid_sync;
            if(request_valid_sync && !request_valid_sync_prev) begin
                m_axis_request.TDATA <= rx_data;
                m_axis_request.TVALID <= 1'b1;
            end else if(m_axis_request.TVALID && m_axis_request.TREADY) begin
               m_axis_request.TVALID <=1'b0; 
            end
        end
    end
    
    //response CDC (ACLK)
    always_ff @(posedge s_axis_response.ACLK) begin
        if(reset) begin
            response_data <= '0;
            s_axis_response.TREADY <= 1'b1;
            
            response_consumed_meta <= 1'b0;
            response_consumed_sync <= 1'b0;
            response_consumed_sync_prev <= 1'b0;
        end else begin
            response_consumed_meta <= response_consumed;
            response_consumed_sync <= response_consumed_meta;
            response_consumed_sync_prev <= response_consumed_sync;
            if(response_consumed_sync && ~response_consumed_sync_prev) begin
                s_axis_response.TREADY <= 1'b1;
            end else if(s_axis_response.TREADY && s_axis_response.TVALID) begin
                response_data <= s_axis_response.TDATA;
                s_axis_response.TREADY <= 1'b0;
            end
        end
    end
    
    
    //Response CDC (SCLK)
    always_ff @(posedge sclk) begin
        if(reset) begin
            tx_data <= '0;
            response_consumed <= 1'b0;
            response_ready_meta <= 1'b1;
            response_ready_sync <= 1'b1;
            response_ready_sync_prev <= 1'b1;
        end else begin
            response_ready_meta <= s_axis_response.TREADY;
            response_ready_sync <= response_ready_meta;
            response_ready_sync_prev <= response_ready_sync;
            if(!response_ready_sync && response_ready_sync_prev) begin
                tx_data <= response_data;
                response_consumed <= 1'b1;
            end else if(tx_data_consumed) begin
                tx_data <= '0;
                response_consumed <= 1'b0;
            end else begin
                response_consumed <= 1'b0;
            end
        end
    end
    
    //SPI RTL
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
                
                //shift
                always @ (negedge sclk or cs_n or posedge reset) begin
                    if(reset || cs_n) begin
                        tx <= '0;
                        tx_data_consumed <= 1'b0;
                    end else if(!cs_n && !CPHA && bit_counter == 0) begin
                        tx_data_consumed <= 1'b1;
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                    end else if(!cs_n && CPHA && bit_counter == 0 && sclk == CPOL) begin
                        tx <= tx_data;
                        tx_data_consumed <= 1'b1;
                    end else if(!cs_n && CPHA && rx_valid) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                        tx_data_consumed <= 1'b0;
                    end else begin
                        tx_data_consumed <= 1'b0;
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
                
                //shift
                always @ (posedge sclk or cs_n or posedge reset) begin
                    if(reset || cs_n) begin
                        tx <= '0;
                        miso <= 1'b0;
                        tx_data_consumed <= 1'b0;
                    end else if(!cs_n && !CPHA && bit_counter == 0) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                        tx_data_consumed <= 1'b1;
                    end else if(!cs_n && CPHA && bit_counter == 0 && sclk == CPOL) begin
                        tx <= tx_data;
                        tx_data_consumed <= 1'b1;
                    end else if(!cs_n && CPHA && rx_valid) begin
                        tx <= tx_data << 1;
                        miso <= tx_data[DATA_WIDTH-1];
                        tx_data_consumed <= 1'b0;
                    end else begin
                        miso <= tx[DATA_WIDTH-1];
                        tx <= tx << 1;
                        tx_data_consumed <= 1'b0;
                    end
                end
            end
        endcase
    endgenerate
    
endmodule
