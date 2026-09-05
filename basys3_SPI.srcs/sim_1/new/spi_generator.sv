class spi_generator #(
    parameter int DATA_WIDTH
);

    virtual spi_if vif;
    mailbox #(spi_stimulus_transaction #(DATA_WIDTH)) mb;
    
    function new(input mailbox #(spi_stimulus_transaction #(DATA_WIDTH)) mb);
        this.mb = mb;
    endfunction

    task run(input int transaction_count = 1000);
        spi_stimulus_transaction #(DATA_WIDTH) transaction;
        for(int i = 0; i<transaction_count; i++) begin
            transaction = new();
            if(transaction.randomize())
                mb.put(transaction);
            else
                $error("Error randomizing stimulus transaction");                
        end
    endtask

endclass

