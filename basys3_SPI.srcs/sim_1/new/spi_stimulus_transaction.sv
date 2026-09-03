class spi_stimulus_transaction #(
    parameter int DATA_WIDTH = 8
);

    //stimulus
    typedef struct {
        logic [DATA_WIDTH-1:0] mosi_data;
        logic [DATA_WIDTH-1:0] tx_data;
    } spi_word;
    
    rand spi_word spi_words[];
    
    constraint words_limit {
        spi_words.size() inside {[1:8]};
    }

endclass
