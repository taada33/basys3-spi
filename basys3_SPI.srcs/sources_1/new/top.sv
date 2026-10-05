`timescale 1ns / 1ps

module top #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_DESTINATIONS = 4
)(
    input logic aclk,
    input logic reset,
    
    input logic [DATA_WIDTH-1:0] opcode,
    input logic [DATA_WIDTH-1:0] address,
    input logic [DATA_WIDTH-1:0] write_data,
    input logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] destination,
    
    input logic start,
    
    output logic busy,
    output logic status,
    output logic [DATA_WIDTH-1:0] read_data
    );
    
    logic [1:0] slave_spi_modes [0:NUM_DESTINATIONS-1];
    
    //SPI bus
    logic mosi;
    logic sclk;
    logic [NUM_DESTINATIONS-1:0] cs_n; 
    logic [NUM_DESTINATIONS-1:0] slave_miso;   
   
    //N-bit encoder used to select the active slave using cs_n signal
    logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] miso_select;
    logic valid_miso_select;
    
    assign valid_miso_select = (~cs_n != '0) && ((~cs_n & (~cs_n - NUM_DESTINATIONS'(1))) == '0);
    
    always_comb begin
        miso_select = 0;
        for(int j = 0; j < $clog2(NUM_DESTINATIONS); j++) begin
            for(int i = 0; i < NUM_DESTINATIONS; i++) begin
                if(i[j] == 1'b1) begin
                    miso_select[j] = miso_select[j] | ~cs_n[i];
                end
            end
        end
    end
    
    //AXI4-Stream host-master interfaces
    axis_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_DESTINATIONS(NUM_DESTINATIONS)
    )host_request_if();
    
    axis_if #(
        .DATA_WIDTH(DATA_WIDTH)
    )master_response_if();
    
    assign host_request_if.ACLK = aclk;
    assign host_request_if.ARESETn = ~reset;
    
    assign master_response_if.ACLK = aclk;
    assign master_response_if.ARESETn = ~reset;
    
    
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_SLAVES(NUM_DESTINATIONS)
    ) spi_master_dut (
        .s_axis_tx(host_request_if),
        .m_axis_rx(master_response_if),
        .cs_n(cs_n),
        .miso(slave_miso[miso_select] & valid_miso_select),
        .sclk(sclk),
        .mosi(mosi)
    );
    
    spi_host_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_DESTINATIONS(NUM_DESTINATIONS)
    ) spi_host_controller_dut (
        .s_axis_response(master_response_if),
        .m_axis_request(host_request_if),
        .slave_spi_modes(slave_spi_modes),
        .opcode(opcode),
        .address(address),
        .write_data(write_data),
        .start(start),
        .destination(destination),
        .busy(busy),
        .status(status),
        .read_data(read_data)
    );
    
    genvar k;
    
    generate
        for(k = 0; k < NUM_DESTINATIONS; k++) begin : gen_slave
            localparam [1:0] MODE = k % 4;
            //AXI4-Stream slave-memory interfaces
            axis_if #(
                .DATA_WIDTH(DATA_WIDTH)
            )slave_request_if();
            
            axis_if #(
                .DATA_WIDTH(DATA_WIDTH)
            )memory_response_if();
            
            assign slave_request_if.ACLK = aclk;
            assign slave_request_if.ARESETn = ~reset;
            
            assign memory_response_if.ACLK = aclk;
            assign memory_response_if.ARESETn = ~reset;
        
            spi_slave #(
                .DATA_WIDTH(DATA_WIDTH),
                .CPOL(MODE[1]),
                .CPHA(MODE[0])
            ) spi_slave_dut (
                .s_axis_response(memory_response_if),
                .m_axis_request(slave_request_if),
                .sclk(sclk),
                .mosi(mosi),
                .cs_n(cs_n[k]),
                .miso(slave_miso[k])
            );
            
            spi_memory_controller #(
                .DATA_WIDTH(DATA_WIDTH)
            ) spi_memory_controller_dut (
                .m_axis_response(memory_response_if),
                .s_axis_request(slave_request_if)
            );
            
            assign slave_spi_modes[k] = MODE;
        end     
    endgenerate
    
    
endmodule
