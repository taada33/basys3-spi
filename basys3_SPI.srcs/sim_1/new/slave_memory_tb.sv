`timescale 1ns / 1ps

module slave_memory_tb;

    localparam int DATA_WIDTH = 8;
    localparam bit CPOL = 0;
    localparam bit CPHA = 1;
    
    localparam logic [DATA_WIDTH-1:0]
        NOP = 0,
        READ = 1,
        WRITE = 2,
        INVALID = 3;
    
    logic reset;
    logic cs_n;
    
    logic mosi;
    logic miso;
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] recovered_miso;
    
    logic aclk = 1'b0;
    logic sclk = CPOL;
    
    always #5ns aclk = ~aclk;
    
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

    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) spi_slave_dut (
        .s_axis_response(response_if),
        .m_axis_request(request_if),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .miso(miso)
    );
    
    spi_memory_controller #(
        .DATA_WIDTH(DATA_WIDTH)
    ) spi_memory_controller_dut (
        .m_axis_response(response_if),
        .s_axis_request(request_if)
    );
    
    task automatic wait_clocks(input int n);
        repeat (n) @(posedge aclk);
    endtask
    
    task automatic check_memory_valid;
        logic check = 1;
        for(int i = 0; i < spi_memory_controller_dut.MEM_DEPTH; i++) begin
            assert(spi_memory_controller_dut.address_valid[i] === 0)
                else check = 0;
        end
        if(check)
        $display("Memory validity has been reset.");
        else begin
        $display("Error resetting memory validity.");
        $fatal;
        end
    endtask
    
    task automatic sclk_clock(input int cycles);
        for(int i = 0; i < 2*cycles; i++) begin
            #50ns;
            sclk = ~sclk;
        end
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
    
    
    
    task automatic mosi_control(input logic [DATA_WIDTH-1:0] tx_data);
        //check CPHA for rules shift/sample rules on mosi
        if(~CPHA) begin
            mosi = tx_data[DATA_WIDTH-1];
            tx_data = tx_data << 1;
        end
        for(int i = 0; i < DATA_WIDTH; i++) begin
            if(~CPHA) begin
            //leading edge - sample
            leading_edge();
            //trailing edge - shift
            trailing_edge;
            if(i < DATA_WIDTH-1) begin
                mosi = tx_data[DATA_WIDTH-1];
                tx_data = tx_data << 1;
            end
            end else begin
            //leading edge - shift
            leading_edge();
            mosi = tx_data[DATA_WIDTH-1];
            tx_data = tx_data << 1;
            //trailing edge - sample
            trailing_edge;
            end
        end
    endtask
    
    task automatic miso_collector();
        //collect miso bits
        logic [DATA_WIDTH-1:0] data;
        for(int i = 0; i < DATA_WIDTH; i++) begin
            //
            if(~CPHA) begin
                leading_edge();
                data = data << 1 | miso;
                trailing_edge();
            end else begin
                leading_edge();
                trailing_edge();
                data = data << 1 | miso;
            end
        end
        recovered_miso = data;
    endtask
    
    task automatic axi_response();
    //monitor axi_response handshake and signals
    endtask
    
    
    task automatic axi_request();
    //monitor axi_request handshake and signals
    //request_if.TREADY - sent from controller
    //request_if.TVALID - sent from slave module
    //request_if.TDATA - sent from slave module
    endtask
    
    task automatic spi_transaction(input [DATA_WIDTH-1:0] opcode, input [DATA_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data = '0);
        //start of transaction, cs_n goes low 
        cs_n = 1'b0;
        recovered_miso = '0;
        //wait tcss, lets say SPI cycle.
        #50ns; //cant remember exactly what i had this as in SPI master, change later.
        
        //write opcode; 2 = WRITE, 1 = READ, 0 = NOP, 3 = INVALID
        tx_data = opcode; 
       
        //1 word transfer.
        fork
            sclk_clock(DATA_WIDTH);
            mosi_control(tx_data);
            miso_collector();
        join
        
        //write address;
        tx_data = address; 
       
        //1 word transfer.
        fork
            sclk_clock(DATA_WIDTH);
            mosi_control(tx_data);
            miso_collector();
        join
        
        //write data;
        tx_data = data;
        
         //1 word transfer.
        fork
            sclk_clock(DATA_WIDTH);
            mosi_control(tx_data);
            miso_collector();
        join
        
        //turnaround dummy;
        tx_data = '0;
        
         //1 word transfer.
        fork
            sclk_clock(DATA_WIDTH);
            mosi_control(tx_data);
            miso_collector();
        join
        
        //dummy data for validate
        tx_data = '0;
        
         //1 word transfer.
        fork
            sclk_clock(DATA_WIDTH);
            mosi_control(tx_data);
            miso_collector();
        join
        
        //dummy data for response
        tx_data = '0;
        
         //1 word transfer.
        fork
            sclk_clock(DATA_WIDTH);
            mosi_control(tx_data);
            miso_collector();
        join
        
        cs_n = 1'b1;
    endtask
        
    initial begin
        //initialize
        reset = 1'b1;
        cs_n = 1'b1;
        recovered_miso = '0;
        
        wait_clocks(2);
        
        @(negedge aclk);
        reset = 1'b0;
        
        check_memory_valid();
        
        wait_clocks(20);
        
//        spi_transaction(READ,DATA_WIDTH'(200));
        spi_transaction(WRITE,DATA_WIDTH'(200),DATA_WIDTH'(255));
        spi_transaction(READ,DATA_WIDTH'(200));
        
        $finish;
    end
endmodule
