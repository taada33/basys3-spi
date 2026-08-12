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
    localparam int CYCLES_SPI = CLK_FREQ / SPI_FREQ;
    localparam int HALF_CYCLES = CYCLES_SPI/2;

    logic clk = 0;
    always #5 clk = ~clk; //100 MHz
    
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
    
    
    task automatic wait_leading_edge(input int polarity);
        if(polarity)
            @(negedge sclk);
        else
            @(posedge sclk);
    endtask
    
    task automatic wait_trailing_edge(input int polarity);
        if(polarity)
                @(posedge sclk);
            else
                @(negedge sclk);
    endtask
    
    task automatic send_and_check(input [DATA_WIDTH-1:0] data, input [SLAVE_SEL_WIDTH-1:0] slave_idx);
    
        
        logic [DATA_WIDTH-1:0] miso_data = '0;
        logic [DATA_WIDTH-1:0] mosi_data = '0;
        slave_select = slave_idx;
        tx_data = data;
        
        tx_start = 1'b1;
        wait_clocks(1);
        tx_start = 1'b0;
        
        //wait 1 clk cycle for IDLE >> ASSERT_CS_N state transition
        wait_clocks(1);
        //check busy flag
        assert(busy == 1'b1)
            else $error("busy not asserted");
            
            
       //wait 1 clk cycle for ASSERT_CS_N >> DATA state transition     
       wait_clocks(1);
       
       assert(sclk == CPOL)
            else $error("sclk polarity incorrect");
       
       for(int i = 0; i<DATA_WIDTH; i++) begin
            if(CPHA) begin
                //leading edge shift (MISO)
                wait_leading_edge(CPOL);
                miso = miso_data[DATA_WIDTH-1];
                miso_data = miso_data << 1;
                
                //trailing edge sample (MOSI)
                wait_trailing_edge(CPOL);
                mosi_data = {mosi_data[DATA_WIDTH-2:0], mosi};
                
            end else begin
                //leading edge sample (MOSI)
                if(i == 0) begin
                    miso = miso_data[DATA_WIDTH-1];
                    miso_data = miso_data << 1;
                    wait_leading_edge(CPOL);
                    mosi_data = {mosi_data[DATA_WIDTH-2:0], mosi};
                end else begin
                    wait_leading_edge(CPOL);
                    mosi_data = {mosi_data[DATA_WIDTH-2:0], mosi};
                end
                //trailing edge shift MISO)
                wait_trailing_edge(CPOL);
                if(i == DATA_WIDTH-1) begin
                    //do nothing
                end else begin
                    miso = miso_data[DATA_WIDTH-1];
                    miso_data = miso_data << 1;
                end
                
            end    
       end
       
       
        
        
        
        
        
        
        
    endtask
    
    
    
    initial begin
    
        int random_slave;
        //init
        reset = 1'b1;
        
        repeat(5) @(posedge clk);
        reset = 1'b0;
        
        
        repeat(20) @(posedge clk);
        //command
        random_slave = $urandom_range(NUM_SLAVES-1,0);
        send_and_check('hA6,random_slave);
        send_and_check('0,random_slave); //dummy bytes
        
        random_slave = $urandom_range(NUM_SLAVES-1,0);
        send_and_check('h3C,random_slave);
        send_and_check('0,random_slave); //dummy bytes
        
        $display("All tests done.");
        $finish;
    end
endmodule
