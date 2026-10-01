`timescale 1ns / 1ps

module spi_host_controller #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_DESTINATIONS = 1
)(
    //AXI4-Stream interfaces
    axis_if.slave  s_axis_response,
    axis_if.master m_axis_request,
    
    input logic [DATA_WIDTH-1:0] opcode,
    input logic [DATA_WIDTH-1:0] address,
    input logic [DATA_WIDTH-1:0] write_data,
    input logic start,
    input logic [((NUM_DESTINATIONS <= 1) ? 1 : $clog2(NUM_DESTINATIONS))-1:0] destination,
    
    output logic busy,
    output logic status,
    output logic [DATA_WIDTH-1:0] read_data
);
    logic [DATA_WIDTH-1:0] address_ff;
    logic [DATA_WIDTH-1:0] write_data_ff;
    
    logic clk;
    logic reset;
    
    logic response_handshake;
    logic request_handshake;
    
    logic start_accepted;

    typedef enum logic [1:0] {
        NOP,
        READ,
        WRITE,
        INVALID
    } command_t;
    command_t command;
    command_t command_ff;
    
    typedef enum logic [2:0] {
        IDLE,
        OPCODE_ACCEPTED,
        ADDRESS_ACCEPTED,
        DATA_ACCEPTED,
        TURNAROUND,
        WAIT_VALIDITY,
        WAIT_RESPONSE
    } state_t;  
    state_t state;
    
    assign clk = m_axis_request.ACLK;
    assign reset = ~m_axis_request.ARESETn;
    
    //response handshake
    assign response_handshake = s_axis_response.TVALID && s_axis_response.TREADY;
    //request handshake
    assign request_handshake = m_axis_request.TVALID && m_axis_request.TREADY;
    
    //opcode decoding block
    always_comb begin
        case (opcode)
            DATA_WIDTH'(0): command = NOP;
            DATA_WIDTH'(1): command = READ;
            DATA_WIDTH'(2): command = WRITE;
            default: command = INVALID;
        endcase
    end
    
    
    
    //fsm
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= IDLE;
            command_ff <= NOP;
            address_ff <= '0;
            write_data_ff <= '0;
            start_accepted <= 1'b0;
            
            busy <= 1'b0;
            status <= '0;
            read_data <= '0;
            
            m_axis_request.TLAST <= 1'b0;
            m_axis_request.TDATA <= '0;
            m_axis_request.TDEST <= '0;
            m_axis_request.TVALID <= 1'b0;
            s_axis_response.TREADY <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    if(~start_accepted) begin
                        m_axis_request.TDATA <= '0;
                        m_axis_request.TVALID <= 1'b0;
                        m_axis_request.TDEST <= '0;
                        s_axis_response.TREADY <= 1'b0;
                        status <= 1'b0;
                        busy <= 1'b0;
                        if(start) begin
                            start_accepted <= 1'b1;
                            if(destination < NUM_DESTINATIONS) begin
                                if(command == READ) begin
                                    busy <= 1'b1;
                                    address_ff <= address;
                                    command_ff <= command;
                                    m_axis_request.TDATA <= opcode;
                                    m_axis_request.TVALID <= 1'b1;
                                    m_axis_request.TDEST <= destination;
                                    s_axis_response.TREADY <= 1'b1;
                                end else if(command == WRITE) begin
                                    busy <= 1'b1;
                                    address_ff <= address;
                                    write_data_ff <= write_data;
                                    command_ff <= command;
                                    m_axis_request.TDATA <= opcode;
                                    m_axis_request.TVALID <= 1'b1;
                                    m_axis_request.TDEST <= destination;
                                    s_axis_response.TREADY <= 1'b1;
                                end
                            end
                        end
                    end else begin
                        if(request_handshake) begin
                            state <= OPCODE_ACCEPTED;
                            m_axis_request.TDATA <= address_ff;
                            start_accepted <= 1'b0;
                        end
                    end
                end
                OPCODE_ACCEPTED: begin
                    //opcode has been accepted, next handshake loads address
                    if(request_handshake) begin
                        state <= ADDRESS_ACCEPTED;
                        if(command_ff == READ) begin
                            m_axis_request.TDATA <= '0;
                            m_axis_request.TVALID <= 1'b1;
                        end else if(command_ff == WRITE) begin
                            m_axis_request.TDATA <= write_data_ff;
                            m_axis_request.TVALID <= 1'b1;
                        end
                        m_axis_request.TVALID <= 1'b1;
                    end
                end
                ADDRESS_ACCEPTED: begin
                    //address has been accepted, next handshake loads data
                    if(request_handshake) begin
                        m_axis_request.TDATA <= '0;
                        state <= DATA_ACCEPTED;
                    end
                end
                DATA_ACCEPTED: begin
                    //data has been accepted, next handshake loads dummy
                    if(request_handshake) begin
                        m_axis_request.TDATA <= '0;
                        m_axis_request.TVALID <= 1'b1;
                        state <= TURNAROUND;
                    end
                end
                TURNAROUND: begin
                    //another dummy work on handshake
                    if(request_handshake) begin
                        state <= WAIT_VALIDITY;
                    end
                end
                WAIT_VALIDITY: begin
                    //reading validity on response handshake and updating status output
                    if(response_handshake) begin
                        status <= s_axis_response.TDATA[0];
                        state <= WAIT_RESPONSE;
                        m_axis_request.TLAST <= 1'b1;
                    end
                end
                WAIT_RESPONSE: begin
                    //reading response if READ command, updating read_data output
                    if(response_handshake) begin
                        if(command_ff == READ) begin
                            read_data <= s_axis_response.TDATA;
                        end
                        state <= IDLE;
                        busy <= 1'b0;
                        m_axis_request.TVALID <= 1'b0;
                        m_axis_request.TLAST <= 1'b0;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule