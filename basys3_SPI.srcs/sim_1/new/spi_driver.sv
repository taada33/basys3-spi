`timescale 1ns / 1ps

class spi_driver #(
    parameter int DATA_WIDTH = 8,
    parameter bit CPOL,
    parameter bit CPHA,
    parameter time SCLK_HALF_PERIOD
);

    virtual spi_if vif;
    mailbox #(spi_stimulus_transaction #(DATA_WIDTH)) mb;
    
    function new(input virtual spi_if intf,
                 input mailbox #(spi_stimulus_transaction #(DATA_WIDTH)) mb);
        this.vif = intf;
        this.mb = mb;
    endfunction

    task run();
        spi_stimulus_transaction #(DATA_WIDTH) transaction;
        
        forever begin
            mb.get(transaction);
            assert_cs_n();
            if(transaction.abort_type == spi_stimulus_transaction #(DATA_WIDTH):: NONE) begin
                drive_words(transaction);
            end else begin
                fork
                    drive_words(transaction);
                    abort_transaction(transaction);
                join_any
                disable fork;
            end
            deassert_cs_n();
        end
    endtask
    
    task assert_cs_n;
        vif.cs_n = 1'b0;
    endtask
    
    task deassert_cs_n;
        vif.cs_n = 1'b1;
    endtask
    
    
    task sampling_edge;
        if(CPOL == CPHA) begin
            @(posedge vif.sclk);
        end else begin
            @(negedge vif.sclk);
        end
    endtask
    
    task pulse_reset;
        vif.reset = 1;
        fork
            @(posedge vif.sclk);
            @(negedge vif.sclk);
            begin
                #SCLK_HALF_PERIOD;
            end
        join_any
        disable fork;
        vif.reset = 0;
    endtask
    
    task abort_transaction(spi_stimulus_transaction #(DATA_WIDTH) transaction);
            for(int word_index = 0; word_index < transaction.spi_words.size(); word_index++) begin
                for(int bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
                    sampling_edge();
                    if(bit_index == transaction.abort_bit_index && word_index == transaction.abort_word_index) begin
                        if(transaction.abort_type == spi_stimulus_transaction #(DATA_WIDTH) :: RESET_ABORT) begin
                            pulse_reset();
                            vif.sclk = CPOL;  
                            return;                     
                        end else begin
                            vif.cs_n = 1;
                            vif.sclk = CPOL;
                            return;
                        end
                    end
                end
            end
    endtask
    
    task drive_words(spi_stimulus_transaction #(DATA_WIDTH) transaction);
        for(int i = 0; i < transaction.spi_words.size(); i++) begin
                            drive_word(transaction.spi_words[i]);
        end
    endtask
    
    //uses the scope resolution operator (::). "Look inside this scope for this name"; since the spi_word
    //struct is defined in the spi_transaction class, not here.
    task drive_word(spi_stimulus_transaction #(DATA_WIDTH)::spi_word word);
            //before leading edge
            vif.sclk = CPOL;
            vif.tx_data = word.tx_data;
            if(!CPHA) begin
                vif.mosi = word.mosi_data[DATA_WIDTH-1];
            end
            
            for(int i = 0; i<DATA_WIDTH; i++) begin
                //leading edge
                #SCLK_HALF_PERIOD;
                vif.sclk = ~vif.sclk;
                if(CPHA) begin
                    vif.mosi = word.mosi_data[DATA_WIDTH-1-i];
                end
                //trailing edge
                #SCLK_HALF_PERIOD;
                vif.sclk = ~vif.sclk;
                if(!CPHA && i < DATA_WIDTH-1) begin
                    vif.mosi = word.mosi_data[DATA_WIDTH-2-i];
                end
            end
            //sclk returns to CPOL
    endtask
endclass