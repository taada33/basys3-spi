`timescale 1ns / 1ps

module spi_master_tb #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_SLAVES = 1,
    parameter int CLK_FREQ = 100_000_000,
    parameter int SPI_FREQ = 10_000_000,
    parameter bit CPOL = 0,
    parameter bit CPHA = 0
)(
    output logic test_done,
    output logic test_pass
);

    localparam int SLAVE_SEL_WIDTH = (NUM_SLAVES <= 1) ? 1 : $clog2(NUM_SLAVES);
    localparam real CLK_PERIOD = 1_000_000_000.0/CLK_FREQ; // 1_000_000_000 ns/s / 100M cycles/s

    logic clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    logic reset;
    
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] rx_data;
    
    logic [SLAVE_SEL_WIDTH-1:0] slave_select;
    logic [NUM_SLAVES-1:0] cs_n;
    
    logic tx_start;
    logic busy;
    logic done;
    
    logic miso;
    logic sclk;
    logic mosi;

spi_master #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SLAVES(NUM_SLAVES),
    .CLK_FREQ(CLK_FREQ),
    .SPI_FREQ(SPI_FREQ),
    .CPOL(CPOL),
    .CPHA(CPHA)
) dut (
    .clk(clk),
    .reset(reset),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .slave_select(slave_select),
    .cs_n(cs_n),
    .tx_start(tx_start),
    .busy(busy),
    .done(done),
    .miso(miso),
    .sclk(sclk),
    .mosi(mosi)
    );
    
    task automatic wait_clocks(input int n);
    repeat (n) @(posedge clk);
    endtask
    
    
    task automatic wait_leading_edge;
        if(CPOL)
            @(negedge sclk);
        else
            @(posedge sclk);
    endtask
    
    task automatic wait_trailing_edge;
        if(CPOL)
                @(posedge sclk);
            else
                @(negedge sclk);
    endtask
    
    task automatic send_and_check(input [DATA_WIDTH-1:0] data, input [SLAVE_SEL_WIDTH-1:0] slave_idx);
    
        logic [DATA_WIDTH-1:0] miso_data;
        logic [DATA_WIDTH-1:0] expected_miso_data;
        logic [DATA_WIDTH-1:0] mosi_data; 
        
        mosi_data = '0;
        
        if(data == '0) begin
            //respond to request with fake data
            miso_data = $urandom;
        end else begin
            //respond with dummy data when master is sending request
            miso_data = '0;
        end
        
        expected_miso_data = miso_data;
        
        
        
        @(negedge clk);
        tx_start = 1'b1;
        slave_select = slave_idx;
        tx_data = data;
        
        @(negedge clk);
        tx_start = 1'b0;
        
        //wait 1 clk cycle for IDLE >> ASSERT_CS_N state transition
        @(negedge clk);
        //check busy flag
        assert(busy == 1'b1)
        else begin
            $error("busy not asserted");
            test_pass = 0;
        end
        
        assert(cs_n[slave_select] == 0 && $countones(cs_n) == NUM_SLAVES-1)
        else begin
            $error("incorrect slave(s) selected");
            test_pass = 0;
        end
            
            
       //wait 1 clk cycle for ASSERT_CS_N >> DATA state transition     
       wait_clocks(1);
       
       assert(sclk == CPOL)
       else begin
            $error("sclk polarity incorrect");
            test_pass = 0;
       end
       
       if(!CPHA) begin
            // preload first MISO bit
            miso = miso_data[DATA_WIDTH-1];
            miso_data = miso_data << 1;
       end
       for(int i = 0; i<DATA_WIDTH; i++) begin
            if(CPHA) begin
                //leading edge shift (MISO)
                wait_leading_edge;
                miso = miso_data[DATA_WIDTH-1];
                miso_data = miso_data << 1;
                
                //trailing edge sample (MOSI)
                wait_trailing_edge;
                mosi_data = {mosi_data[DATA_WIDTH-2:0], mosi};
                
            end else begin
                //leading edge sample (MOSI)
                wait_leading_edge;
                mosi_data = {mosi_data[DATA_WIDTH-2:0], mosi};
                
                //trailing edge shift MISO)
                wait_trailing_edge;
                if(i == DATA_WIDTH-1) begin
                    //do nothing
                end else begin
                    miso = miso_data[DATA_WIDTH-1];
                    miso_data = miso_data << 1;
                end
                
            end    
       end
       
       
       //DEASSERT_CS_N state
       
       @ (posedge done);
       
       assert(sclk == CPOL)
       else begin
            $error("sclk did not converge to CPOL");
            test_pass = 0;
        end
            
       assert(busy == 1'b0)
       else begin
            $error("busy flag did not clear");
            test_pass = 0;
        end
            
       assert(rx_data == expected_miso_data)
       else begin
            $error("miso data mismatch");
            test_pass = 0;
        end
            
        assert(data == mosi_data)
        else begin
            $error("mosi data mismatch");
            test_pass = 0;
        end
        
        wait_clocks(1);
            
        //idle state return
        @(negedge clk);
        
        assert(done == 1'b0)
        else begin
            $error("done flag not cleared");
            test_pass = 0;
        end
        
        assert(cs_n == '1)
        else begin
            $error("Slave select still active");
            test_pass = 0;
        end
        
        if(test_pass)
            $display("PASS: TX=0x%0h RX=0x%0h slave=%0d", data, rx_data, slave_select);
        
    endtask
    
    
    
    initial begin
    
        int random_slave;
        
        test_pass = 1;
        test_done = 0;
        tx_start = 1'b0;
        tx_data = '0;
        slave_select = 0;
        miso = 1'b0;
        reset = 1'b1;
        
        //init       
        wait_clocks(2);
        
        @(negedge clk);
        reset = 1'b0;
        
        
        repeat(20) @(posedge clk);
        //command
        random_slave = $urandom_range(NUM_SLAVES-1,0);
        send_and_check('hA6,random_slave);
        send_and_check('0,random_slave); //dummy bytes
        
        random_slave = $urandom_range(NUM_SLAVES-1,0);
        send_and_check('h3C,random_slave);
        send_and_check('0,random_slave); //dummy bytes
        
        if(test_pass)
            $display("CPOL=%0d CPHA=%0d PASS", CPOL, CPHA);
        else
            $display("CPOL=%0d CPHA=%0d FAILED", CPOL, CPHA);
        
        test_done = 1;
    end
endmodule
