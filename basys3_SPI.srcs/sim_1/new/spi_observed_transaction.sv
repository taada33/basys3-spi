class spi_observed_transaction #(
    parameter int DATA_WIDTH = 8
);
    
    //outputs
    logic [DATA_WIDTH-1:0] miso_data[$];
    logic [DATA_WIDTH-1:0] rx_data[$];
    
    bit aborted;
    bit completed;

endclass
