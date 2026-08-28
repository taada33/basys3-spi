interface spi_if #(
    parameter int DATA_WIDTH = 8
);

    logic sclk;
    logic reset;
    logic mosi;
    logic cs_n;
    logic [DATA_WIDTH-1:0] tx_data;
    
    logic [DATA_WIDTH-1:0] rx_data;
    logic miso;
    logic rx_valid;

endinterface



