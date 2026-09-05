class spi_monitor #(
    parameter int DATA_WIDTH,
    parameter bit CPOL,
    parameter bit CPHA
);
    
    virtual spi_if vif;
    mailbox #(spi_observed_transaction #(DATA_WIDTH)) mb;
    
    bit aborted;
    bit transaction_complete;
  
    function new(input virtual spi_if intf,input mailbox #(spi_observed_transaction #(DATA_WIDTH)) mb);
        this.mb = mb;
        this.vif = intf;
    endfunction
    
    task run();
        spi_observed_transaction #(DATA_WIDTH) transaction;
        forever begin
            @(negedge vif.cs_n);
            transaction = new();
            aborted = 1'b0;
            transaction_complete = 1'b0;
            
            while(!vif.cs_n && !aborted && !transaction_complete) begin
                fork
                    leading_edge();
                    begin
                        @(posedge vif.cs_n);
                        transaction_complete = 1'b1;
                    end
                    begin
                        @(posedge vif.reset);
                        aborted = 1'b1;
                    end
                join_any
                disable fork;
                if(!aborted && !transaction_complete) begin
                    fork
                        monitor_word(transaction);
                        begin
                            @(posedge vif.reset);
                            aborted = 1'b1;
                        end
                        begin
                            @(posedge vif.cs_n);
                            aborted = 1'b1;
                        end
                    join_any
                    disable fork;
                end
            end
            transaction.aborted = aborted;
            transaction.completed = transaction_complete;
            mb.put(transaction);
        end
    endtask
    
    task leading_edge;
        if(CPOL) begin
            @(negedge vif.sclk);
        end else begin
            @(posedge vif.sclk);
        end
    endtask
    
    task trailing_edge;
        if(!CPOL) begin
            @(negedge vif.sclk);
        end else begin
            @(posedge vif.sclk);
        end
    endtask
    
    task monitor_word(spi_observed_transaction #(DATA_WIDTH) transaction);
        logic [DATA_WIDTH-1:0] miso_data = '0;
        logic [DATA_WIDTH-1:0] rx_data = '0;
        
        fork
            begin
                for(int i=0; i < DATA_WIDTH; i++) begin
                    if(CPHA) begin
                        //leading edge (SHIFTS)
                        if(i > 0) begin
                            leading_edge();
                        end
                        
                        //trailing edge (SAMPLES)
                        trailing_edge();
                        miso_data = {miso_data[DATA_WIDTH-2:0],vif.miso};
                    end else begin
                        //leading edge (SAMPLES)
                        if(i > 0) begin
                            leading_edge();
                        end
                        miso_data = {miso_data[DATA_WIDTH-2:0],vif.miso};
                        
                        //trailing edge (SHIFTS)
                        trailing_edge();
                    end
                end
            end
            
            begin
                @(posedge vif.rx_valid);
                rx_data = vif.rx_data;
            end
        join;
        
        transaction.miso_data.push_back(miso_data);
        transaction.rx_data.push_back(rx_data);
    endtask
    
endclass