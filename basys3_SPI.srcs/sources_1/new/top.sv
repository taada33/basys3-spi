`timescale 1ns / 1ps

module top #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_DESTINATIONS = 4,
    parameter int CLK_FREQ = 100_000_000,
    parameter int DEBOUNCE_FREQ = 125
)(
    input logic aclk,
    
    input logic start_btn,
    input logic read_btn,
    input logic write_btn,
    input logic destination_left_btn,
    input logic destination_right_btn,
    
    
    input logic [DATA_WIDTH-1:0] address,
    input logic [DATA_WIDTH-1:0] write_data,
    
    //seven segment display outputs
    output logic [6:0] seg,
    output logic [3:0] an,
    
    //LED outputs
    output logic status_led,
    output logic write_led,
    output logic read_led,
    output logic cpha_led,
    output logic cpol_led,
    output logic [3:0] destination_led
    );
    
    logic busy;
    logic [DATA_WIDTH-1:0] read_data;
    
    logic status;
    logic start;
    logic read_opcode;
    logic write_opcode;
    logic destination_left;
    logic destination_right;
    
    logic [DATA_WIDTH-1:0] opcode;
    logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] destination;
    
    logic reset = 1'b1;
    logic [3:0] reset_count = '0;
    
    always_ff @ (posedge aclk) begin
        reset <= 1'b1;
        if(reset_count > 2) begin
            reset <= 1'b0;
        end else begin
            reset_count <= reset_count + 1;
        end
    end
    
    always_ff @ (posedge aclk) begin
        if(reset) begin
            opcode <= '0;
        end else begin
            case({write_opcode,read_opcode})
                2'b00: begin
                //do nothing.
                end
                2'b01: begin
                opcode <= DATA_WIDTH'(1);
                end
                2'b10: begin
                opcode <= DATA_WIDTH'(2);
                end
                2'b11: begin
                opcode <= DATA_WIDTH'(3);
                end
                default: opcode <= DATA_WIDTH'(0);
            endcase
        end
    end
    
    always_ff @(posedge aclk) begin
        if(reset) begin
            destination <= '0;
        end else begin
            if(destination_right && ~destination_left) begin
                if(destination == NUM_DESTINATIONS-1) begin
                    destination <= '0;                
                end else begin
                    destination <= destination + 1;
                end
            end else if(destination_left && ~destination_right) begin
                if(destination == 0) begin
                    destination <= NUM_DESTINATIONS - 1;                
                end else begin
                    destination <= destination - 1;
                end
            end
        end
    end
    
    logic [1:0] slave_spi_modes [0:NUM_DESTINATIONS-1];
    
    //SPI bus
    logic mosi;
    logic sclk;
    logic [NUM_DESTINATIONS-1:0] cs_n; 
    logic [NUM_DESTINATIONS-1:0] slave_miso;   
   
    //N-bit encoder used to select the active slave using cs_n signal
    logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] miso_select;
    logic valid_miso_select;
    
    assign status_led = status;
    assign write_led = opcode == DATA_WIDTH'(2);
    assign read_led = opcode == DATA_WIDTH'(1);
    assign cpha_led = slave_spi_modes[destination][0];
    assign cpol_led = slave_spi_modes[destination][1];
    assign destination_led = destination == '0 ? 4'b1000 : destination == 1 ? 4'b0100 : destination == 2 ? 4'b0010 : 4'b0001;
    
    active_low_encoder #(
        .WIDTH(NUM_DESTINATIONS)
    ) active_low_encoder_inst (
        .input_n(cs_n),
        .encoded(miso_select),
        .valid(valid_miso_select)
    );
    
    //AXI4-Stream host-master interfaces
    axis_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_DESTINATIONS(NUM_DESTINATIONS)
    )host_request_if();
    
    axis_if #(
        .DATA_WIDTH(DATA_WIDTH)
    )master_response_if();
    
    assign host_request_if.ACLK = aclk;
    assign host_request_if.ARESETn = ~reset;
    
    assign master_response_if.ACLK = aclk;
    assign master_response_if.ARESETn = ~reset;
    
    
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_SLAVES(NUM_DESTINATIONS)
    ) spi_master_inst (
        .s_axis_tx(host_request_if),
        .m_axis_rx(master_response_if),
        .cs_n(cs_n),
        .miso(slave_miso[miso_select] & valid_miso_select),
        .sclk(sclk),
        .mosi(mosi)
    );
    
    spi_host_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_DESTINATIONS(NUM_DESTINATIONS)
    ) spi_host_controller_inst (
        .s_axis_response(master_response_if),
        .m_axis_request(host_request_if),
        .slave_spi_modes(slave_spi_modes),
        .opcode(opcode),
        .address(address),
        .write_data(write_data),
        .start(start),
        .destination(destination),
        .busy(busy),
        .status(status),
        .read_data(read_data)
    );
    
    genvar k;
    
    generate
        for(k = 0; k < NUM_DESTINATIONS; k++) begin : gen_slave
            localparam [1:0] MODE = k % 4;
            //AXI4-Stream slave-memory interfaces
            axis_if #(
                .DATA_WIDTH(DATA_WIDTH)
            )slave_request_if();
            
            axis_if #(
                .DATA_WIDTH(DATA_WIDTH)
            )memory_response_if();
            
            assign slave_request_if.ACLK = aclk;
            assign slave_request_if.ARESETn = ~reset;
            
            assign memory_response_if.ACLK = aclk;
            assign memory_response_if.ARESETn = ~reset;
        
            spi_slave #(
                .DATA_WIDTH(DATA_WIDTH),
                .CPOL(MODE[1]),
                .CPHA(MODE[0])
            ) spi_slave_inst (
                .s_axis_response(memory_response_if),
                .m_axis_request(slave_request_if),
                .sclk(sclk),
                .mosi(mosi),
                .cs_n(cs_n[k]),
                .miso(slave_miso[k])
            );
            
            spi_memory_controller #(
                .DATA_WIDTH(DATA_WIDTH)
            ) spi_memory_controller_inst (
                .m_axis_response(memory_response_if),
                .s_axis_request(slave_request_if)
            );
            
            assign slave_spi_modes[k] = MODE;
        end     
    endgenerate
    
    button_conditioner #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_FREQ(DEBOUNCE_FREQ)
    ) button_conditioner_START (
        .clk(aclk),
        .reset(reset),
        .signal_in(start_btn),
        .signal_out(start)
    );
    
    button_conditioner #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_FREQ(DEBOUNCE_FREQ)
    ) button_conditioner_READ (
        .clk(aclk),
        .reset(reset),
        .signal_in(read_btn),
        .signal_out(read_opcode)
    );
    
    button_conditioner #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_FREQ(DEBOUNCE_FREQ)
    ) button_conditioner_WRITE (
        .clk(aclk),
        .reset(reset),
        .signal_in(write_btn),
        .signal_out(write_opcode)
    );
    
    button_conditioner #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_FREQ(DEBOUNCE_FREQ)
    ) button_conditioner_DEST_LEFT (
        .clk(aclk),
        .reset(reset),
        .signal_in(destination_left_btn),
        .signal_out(destination_left)
    );
    
    button_conditioner #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_FREQ(DEBOUNCE_FREQ)
    ) button_conditioner_DEST_RIGHT (
        .clk(aclk),
        .reset(reset),
        .signal_in(destination_right_btn),
        .signal_out(destination_right)
    );
    
    seven_seg seven_seg_inst (
        .clk(aclk),
        .reset(reset),
        .left_data(address),
        .right_data(opcode == DATA_WIDTH'(1) ? read_data : write_data),
        .seg(seg),
        .an(an)
    );
    
    
endmodule
