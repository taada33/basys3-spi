`timescale 1ns / 1ps

module top_tb;

localparam int DATA_WIDTH = 8;
localparam int NUM_SLAVES = 4;
localparam int CLK_FREQ = 100_000_000;
localparam int SPI_FREQ = 10_000_000;

logic [1:0][1:0] test_done;
logic [1:0][1:0] test_pass;

genvar i, j;

generate    
    for(i = 0; i < 2; i++) begin : gen_cpha
        for(j = 0; j < 2; j++) begin : gen_cpol
            spi_master_tb # (
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_SLAVES(NUM_SLAVES),
                .CLK_FREQ(CLK_FREQ),
                .SPI_FREQ(SPI_FREQ),
                .CPHA(i),
                .CPOL(j)
            )spi_master_tb_dut (
                .test_done(test_done[i][j]),
                .test_pass(test_pass[i][j])
            );
        end    
    end
endgenerate 

initial begin
    
    wait(&test_done);

    for(int k = 0; k<2; k++) begin
        for(int l = 0; l<2; l++) begin
            assert(test_pass[k][l])
                else $error("Test CPHA = %0d and CPOL = %0d failed",k,l);
        end
    end  
    
    if(&test_pass)
        $display("All SPI mode tests Passed");
      
    $finish;

end

    

endmodule
