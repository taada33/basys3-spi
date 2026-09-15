interface axis_if #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_DESTINATIONS = 1
);

    logic ACLK;
    logic ARESETn;
    
    logic [DATA_WIDTH-1:0] TDATA;
    logic TVALID;
    logic TREADY;
    logic TLAST;
    logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] TDEST;
    
    modport master (
        output TDATA,
        output TVALID,
        output TLAST,
        output TDEST,
        
        input TREADY,
        
        input ACLK,
        input ARESETn
    );
    
    modport slave (
        output TREADY,
        
        input TDATA,
        input TVALID,
        input TLAST,
        input TDEST,
        
        input ACLK,
        input ARESETn
    );
    

endinterface