`timescale 1ns / 1ps

// TODO: Retain status until the next completed transaction.
// TODO: Drive AXI4-Stream TDEST for slave selection.

module spi_host_controller #(
    parameter int DATA_WIDTH = 8
)(
    //AXI4-Stream interfaces
    axis_if.slave  s_axis_response,
    axis_if.master m_axis_request,
    
    input logic [DATA_WIDTH-1:0] opcode,
    input logic [DATA_WIDTH-1:0] address,
    input logic [DATA_WIDTH-1:0] write_data,
    input logic start,
    
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
        SEND_OPCODE,
        SEND_ADDRESS,
        SEND_DATA,
        SEND_DUMMY,
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
            
            busy <= 1'b0;
            status <= 1'b0;
            read_data <= '0;
            
            m_axis_request.TLAST <= 1'b0;
            m_axis_request.TDATA <= '0;
            m_axis_request.TVALID <= 1'b0;
            s_axis_response.TREADY <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    m_axis_request.TDATA <= '0;
                    m_axis_request.TVALID <= 1'b0;
                    s_axis_response.TREADY <= 1'b0;
                    status <= 1'b0;
                    busy <= 1'b0;
                    if(start) begin
                        if(command == READ) begin
                            busy <= 1'b1;
                            address_ff <= address;
                            command_ff <= command;
                            state <= SEND_OPCODE;
                            m_axis_request.TDATA <= opcode;
                            m_axis_request.TVALID <= 1'b1;
                            s_axis_response.TREADY <= 1'b1;
                        end else if(command == WRITE) begin
                            busy <= 1'b1;
                            address_ff <= address;
                            write_data_ff <= write_data;
                            command_ff <= command;
                            state <= SEND_OPCODE;
                            m_axis_request.TDATA <= opcode;
                            m_axis_request.TVALID <= 1'b1;
                            s_axis_response.TREADY <= 1'b1;
                        end
                    end
                end
                SEND_OPCODE: begin
                    //sending opcode on handshake then loading the address
                    if(request_handshake) begin
//                        m_axis_request.TVALID <= 1'b0;
                        state <= SEND_ADDRESS;
                        m_axis_request.TDATA <= address_ff;
                        m_axis_request.TVALID <= 1'b1;
                    end
                end
                SEND_ADDRESS: begin
                    //sending address on handshake then loading data if write otherwise dummy
                    if(request_handshake) begin
                        if(command_ff == READ) begin
                            m_axis_request.TDATA <= '0;
                            m_axis_request.TVALID <= 1'b1;
                        end else if(command_ff == WRITE) begin
                            m_axis_request.TDATA <= write_data_ff;
                            m_axis_request.TVALID <= 1'b1;
                        end
                        state <= SEND_DATA;
                    end
                end
                SEND_DATA: begin
                    //sending data on handshake then loading dummy to exchange for memory response
                    if(request_handshake) begin
                        m_axis_request.TDATA <= '0;
                        m_axis_request.TVALID <= 1'b1;
                        m_axis_request.TLAST <= 1'b1;
                        state <= SEND_DUMMY;
                    end
                end
                SEND_DUMMY: begin
                    if(request_handshake) begin
                        m_axis_request.TVALID <= 1'b0;
                        m_axis_request.TLAST <= 1'b0;
                        state <= WAIT_RESPONSE;
                    end
                end
                WAIT_RESPONSE: begin
                    if(response_handshake) begin
                        if(command_ff == READ) begin
                            read_data <= s_axis_response.TDATA;
                            status <= 1'b1;
                        end else if(command_ff == WRITE) begin
                            status <= s_axis_response.TDATA == DATA_WIDTH'(1) ? 1'b1 : 1'b0;
                        end
                        state <= IDLE;
                        busy <= 1'b0;
                    end
                end
                default: state <= IDLE;
            endcase
            
        end
    end


endmodule