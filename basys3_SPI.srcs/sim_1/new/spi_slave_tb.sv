`timescale 1ns / 1ps

module spi_slave_tb #(
    parameter int DATA_WIDTH = 8,
    parameter bit CPOL = 0,
    parameter bit CPHA = 0
)(
    output logic test_done,
    output logic test_pass
);
    logic sclk = CPOL;
    
    logic reset;
    logic mosi;
    logic cs_n;
    logic [DATA_WIDTH-1:0] tx_data;
    
    logic [DATA_WIDTH-1:0] rx_data;
    logic miso;
    logic rx_valid;
    
    localparam time SCLK_HALF_PERIOD = 5ns;
    
    always #SCLK_HALF_PERIOD sclk = !cs_n ? ~sclk : CPOL;
    
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) dut (
        .sclk(sclk),
        .reset(reset),
        .mosi(mosi),
        .cs_n(cs_n),
        .tx_data(tx_data),
        
        .rx_data(rx_data),
        .miso(miso),
        .rx_valid(rx_valid)
    );
    
    task automatic assert_cs_n;
        cs_n = 0;
        wait(SCLK_HALF_PERIOD);
    endtask
    
    task automatic de_assert_cs_n;
        cs_n = 0;
        wait(SCLK_HALF_PERIOD);
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
    
    task automatic send_and_check(input [DATA_WIDTH-1:0] data);
    //
    endtask
    
    
    
    initial begin
    
    test_pass = 1;
    test_done = 0;
    
    mosi = 1'b0;
    reset = 1'b0;
    
    
    
    end
    
    

endmodule
