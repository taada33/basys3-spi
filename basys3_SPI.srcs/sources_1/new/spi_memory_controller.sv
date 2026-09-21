`timescale 1ns / 1ps

module spi_memory_controller #(
    parameter int DATA_WIDTH = 8
)(
    //AXI4-Stream interfaces
    axis_if.master  m_axis_response,
    axis_if.slave s_axis_request
    );
    
    localparam int MEM_DEPTH = 2**DATA_WIDTH;
    
    logic [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    logic clk;
    logic reset;
    
    logic response_handshake;
    logic request_handshake;
    
    logic [DATA_WIDTH-1:0] opcode;
    logic [DATA_WIDTH-1:0] address;
    
    typedef enum logic [1:0] {
        OPCODE,
        ADDRESS,
        DATA,
        RESPONSE
    } state_t;  
    state_t state;
    
    typedef enum logic [1:0] {
        NOP,
        READ,
        WRITE,
        INVALID
    } command_t;
    command_t command;
    
    assign clk = s_axis_request.ACLK;
    assign reset = ~s_axis_request.ARESETn;
    
    //response handshake
    assign response_handshake = m_axis_response.TVALID && m_axis_response.TREADY;
    //request handshake
    assign request_handshake = s_axis_request.TVALID && s_axis_request.TREADY;
    
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
            state <= OPCODE;
            opcode <= '0;
            address <= '0;
            m_axis_response.TVALID <= 1'b0;
            s_axis_request.TREADY <= 1'b0;
            m_axis_response.TDATA <= '0;
        end else begin
            case(state)
                OPCODE: begin
                    s_axis_request.TREADY <= 1'b1;
                    if(request_handshake) begin
                        state <= ADDRESS;
                        opcode <= s_axis_request.TDATA;
                        s_axis_request.TREADY <= 1'b0;
                    end
                end
                ADDRESS: begin
                    if(command == READ || command == WRITE) begin
                        s_axis_request.TREADY <=1'b1;
                        if(request_handshake) begin
                        state <= DATA;
                        address <= s_axis_request.TDATA;                        
                        end
                    end else begin
                        state <= OPCODE;
                        s_axis_request.TREADY <= 1'b1;
                    end
                end
                DATA: begin
                    if(request_handshake) begin
                        state <= RESPONSE;
                        s_axis_request.TREADY <= 1'b0;
                        if(command == WRITE) memory[address] <= s_axis_request.TDATA;
                    end
                end
                RESPONSE: begin
                    case(command)
                        READ: begin
                            m_axis_response.TDATA <= memory[address];
                            m_axis_response.TVALID <= 1'b1;
                            if(response_handshake) begin
                                state <= OPCODE;
                                m_axis_response.TVALID <= 1'b0;
                                s_axis_request.TREADY <= 1'b1;
                            end
                        end
                        WRITE: begin
                            m_axis_response.TDATA <= DATA_WIDTH'(1);
                            m_axis_response.TVALID <= 1'b1;
                            if(response_handshake) begin
                                state <= OPCODE;
                                m_axis_response.TVALID <= 1'b0;
                                s_axis_request.TREADY <= 1'b1;
                            end
                        end
                        default: begin
                            state <= OPCODE;
                            s_axis_request.TREADY <= 1'b1;
                            m_axis_response.TVALID <= 1'b0;
                        end
                    endcase
                end
                default: begin
                    state <= OPCODE;
                    s_axis_request.TREADY <= 1'b1;
                    m_axis_response.TVALID <= 1'b0;
                end
            endcase
        end    
    end
    
endmodule
