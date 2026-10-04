`timescale 1ns / 1ps

module host_master_tb();

    localparam int DATA_WIDTH = 8;
    localparam int NUM_DESTINATIONS = 1;
    localparam bit CPOL = 0;
    localparam bit CPHA = 0;
    
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
    logic cs_n;
    
    //slave outputs
    logic miso;
    
    //tb signals
    logic [DATA_WIDTH-1:0] recovered_mosi;
    logic [DATA_WIDTH-1:0] miso_data;
    
    //AXI4-Stream interfaces
    axis_if #(
        .DATA_WIDTH(DATA_WIDTH)
    )request_if();
    
    axis_if #(
        .DATA_WIDTH(DATA_WIDTH)
    )response_if();
    
    assign request_if.ACLK = aclk;
    assign request_if.ARESETn = ~reset;
    
    assign response_if.ACLK = aclk;
    assign response_if.ARESETn = ~reset;
    
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) spi_master_dut (
        .s_axis_tx(request_if),
        .m_axis_rx(response_if),
        .cs_n(cs_n),
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi)
    );
    
    spi_host_controller #(
        .DATA_WIDTH(DATA_WIDTH)
    ) spi_host_controller_dut (
        .s_axis_response(response_if),
        .m_axis_request(request_if),
        .opcode(opcode),
        .address(address),
        .write_data(write_data),
        .start(start),
        .destination(destination),
        .busy(busy),
        .status(status),
        .read_data(read_data)
    );
    
    typedef enum logic [1:0] {
        NOP,
        READ,
        WRITE,
        INVALID
    } command_t;
    
    
    task automatic wait_clocks(input int n);
        repeat (n) @(posedge aclk);
    endtask
    
    task automatic leading_edge();
        if(CPOL) begin
            @(negedge sclk);
        end else begin
            @(posedge sclk);
        end
    endtask
    
    task automatic trailing_edge();
        if(CPOL) begin
            @(posedge sclk);
        end else begin
            @(negedge sclk);
        end
    endtask
    
    task automatic mosi_collector;
        //collects mosi outputs and confirm correct mosi behaviour
        logic [DATA_WIDTH-1:0] data = '0;
        for(int i = 0; i < DATA_WIDTH; i++) begin
            if(~CPHA) begin
                leading_edge();
                data = data << 1 | mosi;
                trailing_edge();
            end else begin
                leading_edge();
                trailing_edge();
                data = data << 1 | mosi;
            end
        end
        recovered_mosi = data;
    
    endtask
    
    task automatic miso_control(input logic [DATA_WIDTH-1:0] data);
        //corresponding miso bits from slave.
        if(~CPHA) begin
            miso = data[DATA_WIDTH-1];
            data = data << 1;
        end
        for(int i = 0; i < DATA_WIDTH; i++) begin
            if(~CPHA) begin
                //leading edge - sample
                leading_edge();
                //trailing edge - shift
                trailing_edge();
                if(i < DATA_WIDTH-1) begin
                    miso = data[DATA_WIDTH-1];
                    data = data << 1;
                end
            end else begin
                //leading edge - shift
                leading_edge();
                miso = data[DATA_WIDTH-1];
                data = data << 1;
                //trailing edge - sample
                trailing_edge();
            end
        end
    endtask
    
    
    task automatic spi_transaction(input [DATA_WIDTH-1:0] opcode_in, input [DATA_WIDTH-1:0] address_in, input [DATA_WIDTH-1:0] data_in = '0, input [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] destination_in = 0);
    //
    opcode = opcode_in;
    address = address_in;
    write_data = data_in;
    destination = destination_in;
    
    //IDLE
    @(negedge aclk);
    start = 1;
    @(negedge aclk);
    start = 0;
    //SEND_OPCODE
    miso_data = '0;
    fork
        miso_control(miso_data);
        mosi_collector();
    join
    //SEND_ADDRESS
    miso_data = '0;
    fork
        miso_control(miso_data);
        mosi_collector();
    join
    //SEND_DATA
    miso_data = '0;
    fork
        miso_control(miso_data);
        mosi_collector();
    join
    //SEND_DUMMY
    miso_data = '0;
    fork
        miso_control(miso_data);
        mosi_collector();
    join
    //WAIT_VALIDITY
    miso_data = DATA_WIDTH'(1);
    fork
        miso_control(miso_data);
        mosi_collector();
    join
    //WAIT_RESPONSE
    miso_data = '1;
    fork
        miso_control(miso_data);
        mosi_collector();
    join
    endtask
    
    initial begin
    //initialize
    miso_data = '0;
    recovered_mosi = '0;
    
    reset = 1'b1;
    start = 1'b0;
    
    wait_clocks(2);
    
    @(negedge aclk);
    reset = 1'b0;
    
    wait_clocks(20);
    
//    spi_transaction(READ,DATA_WIDTH'(200));
    spi_transaction(WRITE,DATA_WIDTH'(200),DATA_WIDTH'(255));
    spi_transaction(READ,DATA_WIDTH'(200));
    
    $finish;
    end
endmodule
