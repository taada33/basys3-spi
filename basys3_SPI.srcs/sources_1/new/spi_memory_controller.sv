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
    logic address_valid [0:MEM_DEPTH-1];
    
    logic clk;
    logic reset;
    
    logic response_handshake;
    logic request_handshake;
    
    logic response_handshake_complete;
    logic request_handshake_complete;
    
    logic [DATA_WIDTH-1:0] opcode;
    logic [DATA_WIDTH-1:0] address;
    
    typedef enum logic [2:0] {
        OPCODE,
        ADDRESS,
        DATA,
        TURNAROUND,
        VALIDITY,
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
            
            response_handshake_complete <= 1'b0;
            request_handshake_complete <= 1'b0;
            
            for(int i = 0; i < MEM_DEPTH; i++) begin
                address_valid[i] <= '0;
            end
        end else begin
            case(state)
                OPCODE: begin
                    s_axis_request.TREADY <= 1'b1;
                    if(request_handshake) begin
                        state <= ADDRESS;
                        opcode <= s_axis_request.TDATA;
                    end
                end
                ADDRESS: begin
                    if(command == READ || command == WRITE) begin
                        if(request_handshake) begin
                        state <= DATA;
                        address <= s_axis_request.TDATA;                        
                        end
                    end else begin
                        state <= OPCODE;
                    end
                end
                DATA: begin
                    if(request_handshake) begin
                        state <= TURNAROUND;
                        if(command == WRITE) begin
                            memory[address] <= s_axis_request.TDATA;
                            address_valid[address] <= 1'b1;
                        end
                        m_axis_response.TDATA <= (command == WRITE || address_valid[address]) ? DATA_WIDTH'(1) : '0;
                        m_axis_response.TVALID <= 1'b1;
                    end
                end
                TURNAROUND: begin
                    if(response_handshake) begin
                        m_axis_response.TVALID <= 1'b0;
                        response_handshake_complete <= 1'b1;
                    end
                    if(request_handshake) begin
                        request_handshake_complete <= 1'b1;
                    end
                    if((response_handshake_complete || response_handshake) && (request_handshake_complete || request_handshake)) begin
                        state <= VALIDITY;
                        response_handshake_complete <= 1'b0;
                        request_handshake_complete <= 1'b0;
                    end
                end
                VALIDITY: begin
                    case(command)
                        READ: begin
                            if(address_valid[address]) begin
                                m_axis_response.TDATA <= memory[address];
                            end
                            m_axis_response.TVALID <= ~response_handshake_complete;
                            
                            if(response_handshake) begin
                                m_axis_response.TVALID <= 1'b0;
                                response_handshake_complete <= 1'b1;
                            end
                            
                            if(request_handshake) begin
                                request_handshake_complete <= 1'b1;
                            end
                            
                            if((response_handshake_complete || response_handshake) && (request_handshake_complete || request_handshake)) begin
                                state <= RESPONSE;
                                response_handshake_complete <= 1'b0;
                                request_handshake_complete <= 1'b0;
                            end
                        end
                        WRITE: begin
                            m_axis_response.TDATA <= DATA_WIDTH'(1);
                            m_axis_response.TVALID <= ~response_handshake_complete;
                            if(response_handshake) begin
                                m_axis_response.TVALID <= 1'b0;
                                response_handshake_complete <= 1'b1;
                            end
                            
                            if(request_handshake) begin
                                request_handshake_complete <= 1'b1;
                            end
                            
                            if((response_handshake_complete || response_handshake) && (request_handshake_complete || request_handshake)) begin
                                state <= RESPONSE;
                                response_handshake_complete <= 1'b0;
                                request_handshake_complete <= 1'b0;
                            end
                        end
                        default: begin
                            state <= RESPONSE;
                            s_axis_request.TREADY <= 1'b1;
                            m_axis_response.TVALID <= 1'b0;
                        end
                    endcase
                end
                RESPONSE: begin
                    if(request_handshake) begin
                        state <= OPCODE;
                    end
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
