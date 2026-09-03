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
            for(int i = 0; i < transaction.spi_words.size(); i++) begin
                drive_word(transaction.spi_words[i]);
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