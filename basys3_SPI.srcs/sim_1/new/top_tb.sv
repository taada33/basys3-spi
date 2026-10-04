`timescale 1ns / 1ps

module top_tb;
    localparam int DATA_WIDTH = 8;
    localparam int NUM_DESTINATIONS = 4;
    localparam int MEM_DEPTH = 2**DATA_WIDTH;
    
    logic [1:0] slave_spi_modes [0:NUM_DESTINATIONS-1];
    
    logic reset;
    
    logic aclk = 1'b0;
    
    always #5ns aclk = ~aclk;
    
    //host inputs
    logic [DATA_WIDTH-1:0] opcode;
    logic [DATA_WIDTH-1:0] address;
    logic [DATA_WIDTH-1:0] write_data;
    logic start;
    logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] destination;
    
    //host outputs
    logic busy;
    logic status;
    logic [DATA_WIDTH-1:0] read_data;
    
    //master outputs
    logic mosi;
    logic sclk;
    logic [NUM_DESTINATIONS-1:0] cs_n;
    
    //TB memory reference
    logic [DATA_WIDTH-1:0] memory [0:NUM_DESTINATIONS-1][0:MEM_DEPTH-1];
    logic address_valid [0:NUM_DESTINATIONS-1][0:MEM_DEPTH-1];
    
    typedef enum logic [1:0] {
        NOP,
        READ,
        WRITE,
        INVALID
    } command_t;
    
    
    //N-bit encoder used to select the active slave using cs_n signal
    logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] miso_select;
    logic valid_miso_select;
    logic [NUM_DESTINATIONS-1:0] slave_miso;
    
    assign valid_miso_select = (~cs_n != 0) && (~cs_n & (~cs_n - 1'b1)) == 0;
    
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
    
    task automatic wait_clocks(input int n);
        repeat (n) @(posedge aclk);
    endtask
    
    
    task automatic drive_host(input logic [DATA_WIDTH-1:0] opcode_in, input logic [DATA_WIDTH-1:0] address_in, input logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] destination_in, input logic [DATA_WIDTH-1:0] write_data_in = '0);
        opcode = opcode_in;
        address = address_in;
        write_data = write_data_in;
        destination = destination_in;
        
        wait_clocks(3);
        
        @(negedge aclk);
        start = 1'b1;
        @(negedge aclk);
        start = 1'b0;
        
        @(negedge busy); // wait for transaction to complete
        
        if(opcode_in == WRITE) begin
            memory[destination_in][address_in] = write_data_in;
            address_valid[destination_in][address_in] = 1'b1;
        end
        
        assert(address_valid[destination_in][address_in] == status)
            $display("correct status");
        else 
            $display("mismatched status");        
        
        if(opcode_in == READ && address_valid[destination_in][address_in]) begin
            assert(memory[destination_in][address_in] == read_data)
                $display("read success");
            else
                $display("read failed");
        end
        
        //do assertions to check all host output values;
        
        //    logic busy - skipping because we're using this signal already to verify correct behaviour.
//        assert(opcode_in == READ ? status == 1'b1
        //    logic [DATA_WIDTH-1:0] read_data;
        
    endtask
    
    initial begin
        start = 1'b0;
        reset = 1'b1;
        
        for(int i = 0; i < NUM_DESTINATIONS; i++) begin
            for(int j = 0; j < MEM_DEPTH; j++) begin
                address_valid[i][j] = 1'b0;
            end
        end
        
        wait_clocks(5);
        
        @(negedge aclk);
        reset = 1'b0;
        
        wait_clocks(5);
        
        drive_host(READ,8'hC8,0);
        drive_host(WRITE,8'hC8,0,8'h33);
        drive_host(READ,8'hC8,0);
        
        drive_host(READ,8'hC8,1);
        drive_host(WRITE,8'hC8,1,8'h33);
        drive_host(READ,8'hC8,1);
        
        drive_host(READ,8'hC8,2);
        drive_host(WRITE,8'hC8,2,8'h33);
        drive_host(READ,8'hC8,2);
        
        drive_host(READ,8'hC8,3);
        drive_host(WRITE,8'hC8,3,8'h33);
        drive_host(READ,8'hC8,3);
    
        $finish;
    end

    
    
endmodule
