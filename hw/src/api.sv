`ifndef FCART_VERSION
`define FCART_VERSION 16'h0000
`endif

module api (
    input  logic clk,
    input  logic reset,
    output logic fpga_irq,

    output logic [31:0] wr_reg,
    output logic [3:0] wr_reg_addr,
    output logic wr_reg_changed,
    input logic [31:0] ev_reg,

    sdram_bus.controller ram,
    output logic ram_refresh,

    input logic [15:0] rd_data,
    input logic rd_valid,
    output logic rd_ready,
    output logic [15:0] wr_data,
    input logic wr_valid,
    output logic wr_ready,
    input logic start
);
    localparam [15:0] VERSION = `FCART_VERSION;
    localparam CMD_READ_MEM = 8'd0;
    localparam CMD_WRITE_MEM = 8'd1;
    localparam CMD_READ_REG = 8'd2;
    localparam CMD_WRITE_REG = 8'd3;

    enum logic [1:0] {
        STATE_IDLE,
        STATE_CMD,
        STATE_ADDR,
        STATE_DATA
    } state;

    logic [7:0] cmd;
    logic [3:0] reg_addr;
    logic [31:0] got_reg;
    logic word_cnt;
    logic ram_busy;

    assign fpga_irq = (got_reg != ev_reg);
    assign ram.we   = (state == STATE_DATA && cmd == CMD_WRITE_MEM);
    assign ram.wm   = 2'b00;  // Always write full word

    always_comb begin
        rd_ready = 0;
        wr_ready = 0;
        wr_data  = '0;

        case (state)
            STATE_IDLE: ;
            STATE_CMD:  rd_ready = 1;
            STATE_ADDR: rd_ready = 1;
            STATE_DATA: begin
                if (cmd == CMD_WRITE_MEM) begin
                    rd_ready = !ram_busy;
                end else if (cmd == CMD_WRITE_REG) begin
                    rd_ready = 1;
                end else if (cmd == CMD_READ_MEM) begin
                    if (ram.ack) begin
                        wr_ready = 1;
                        wr_data  = {ram.data_read[7:0], ram.data_read[15:8]};
                    end
                end else if (cmd == CMD_READ_REG) begin
                    wr_ready = 1;
                    if (reg_addr == 4'd1) begin
                        wr_data = (word_cnt == 0) ? {ev_reg[7:0], ev_reg[15:8]} : {got_reg[23:16], got_reg[31:24]};
                    end else if (reg_addr == 4'd2) begin
                        wr_data = (word_cnt == 0) ? {VERSION[7:0], VERSION[15:8]} : 16'd0;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        ram.req <= 0;
        ram_refresh <= 0;

        if (reset) begin
            state <= STATE_IDLE;
            got_reg <= '1;
            wr_reg_changed <= 0;
        end else begin
            if (start) begin
                state <= STATE_CMD;
                word_cnt <= '0;
                ram_busy <= 0;
            end

            if (ram.ack) ram_busy <= 0;

            case (state)
                STATE_IDLE: ;

                STATE_CMD: begin
                    if (rd_valid) begin
                        cmd                <= rd_data[15:8];
                        ram.address[21:15] <= rd_data[6:0];
                        state              <= STATE_ADDR;

                        ram_refresh        <= 1;
                    end
                end

                STATE_ADDR: begin
                    if (rd_valid) begin
                        ram.address[14:7] <= rd_data[15:8];
                        ram.address[6:0]  <= rd_data[7:1];
                        reg_addr          <= rd_data[3:0];
                        state             <= STATE_DATA;

                        // Prefetch first read
                        if (cmd == CMD_READ_MEM) begin
                            ram.req  <= 1;
                            ram_busy <= 1;
                        end
                    end
                end

                STATE_DATA: begin
                    if (cmd == CMD_WRITE_MEM) begin
                        if (ram.ack) begin
                            ram.address <= ram.address + 1;
                        end else if (!ram_busy && rd_valid) begin
                            ram.data_write <= {rd_data[7:0], rd_data[15:8]};
                            ram.req <= 1;
                            ram_busy <= 1;
                        end
                    end else if (cmd == CMD_READ_MEM) begin
                        if (ram.ack) begin
                            ram.address <= ram.address + 1;
                        end else if (!ram_busy && wr_valid) begin
                            ram.req  <= 1;
                            ram_busy <= 1;
                        end
                    end else if (cmd == CMD_WRITE_REG) begin
                        if (rd_valid) begin
                            if (word_cnt == 0) begin
                                wr_reg[15:0] <= {rd_data[7:0], rd_data[15:8]};
                                word_cnt <= 1;
                            end else begin
                                wr_reg[31:16] <= {rd_data[7:0], rd_data[15:8]};
                                wr_reg_changed <= !wr_reg_changed;
                                wr_reg_addr <= reg_addr;
                                state <= STATE_IDLE;
                            end
                        end
                    end else if (cmd == CMD_READ_REG) begin
                        if (wr_valid) begin
                            if (reg_addr == 4'd1) begin
                                got_reg <= ev_reg;
                            end

                            if (word_cnt == 0) begin
                                word_cnt <= 1;
                            end else begin
                                state <= STATE_IDLE;
                            end
                        end
                    end
                end

                default: ;
            endcase
        end
    end


`ifdef DEBUG
    logic [21:0] debug_ram_address = ram.address;
    logic [15:0] debug_ram_data_read = ram.data_read;
    logic [15:0] debug_ram_data_write = ram.data_write;
    logic [ 1:0] debug_state = state;
`endif
endmodule
