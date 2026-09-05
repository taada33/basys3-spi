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
    
    typedef enum logic [1:0] {
        NONE,
        RESET_ABORT,
        CS_ABORT
    } abort_type_t;  
    
    rand abort_type_t abort_type;
    
    constraint abort_probability {
        abort_type dist {
            NONE := 70,
            RESET_ABORT := 15,
            CS_ABORT := 15
        };
    };
    
    rand int abort_bit_index;
    
    constraint abort_bit_index_limit {
        if(abort_type == NONE)
            abort_bit_index == 0;
        else
            abort_bit_index inside {[0:DATA_WIDTH-1]};
    };
    
    rand int abort_word_index;
    
    constraint abort_word_index_limit {
        //begin/end behaviour not needed since constraint blocks
        //aren't procedural code - inside these block
        //if/else are conditional constraints.
        if(abort_type == NONE)
            //the constraint solver must choose values such that
            //abort_word_index equals 0
            abort_word_index == 0;
        else
            abort_word_index inside {[0:spi_words.size()-1]};
    };
    
    //can vpotentially add random variable to determine on which
    //edge to initiate the abortion - ie sample edge 
    //or shifting edge
    
endclass
