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

    input logic [15:0] rd_data,
    input logic rd_valid,
    output logic rd_ready,
    output logic [15:0] wr_data,
    input logic wr_valid,
    output logic wr_ready,
    input logic start
);
    localparam [15:0] VERSION = `FCART_VERSION;
    localparam CMD_READ_MEM = 2'd0;
    localparam CMD_WRITE_MEM = 2'd1;
    localparam CMD_READ_REG = 2'd2;
    localparam CMD_WRITE_REG = 2'd3;

    enum logic [1:0] {
        STATE_IDLE,
        STATE_CMD,
        STATE_ADDR,
        STATE_DATA
    } state;

    logic [1:0] cmd;
    logic [3:0] reg_addr;
    logic [31:0] got_reg;
    logic word_cnt;
    logic ram_busy;

    assign fpga_irq = (got_reg != ev_reg);
    assign ram.we   = (cmd == CMD_WRITE_MEM);
    assign ram.wm   = 2'b00;  // Always write full word

    always_ff @(posedge clk) begin
        ram.req  <= 0;
        rd_ready <= 0;
        wr_ready <= 0;

        if (reset) begin
            state <= STATE_IDLE;
            got_reg <= '1;
            wr_reg_changed <= 0;
        end else begin
            if (start) begin
                state <= STATE_CMD;
            end

            if (ram.ack && state == STATE_DATA) begin
                ram.address <= ram.address + 1;
                if (cmd == CMD_READ_MEM) begin
                    wr_ready <= 1;
                    wr_data  <= {ram.data_read[7:0], ram.data_read[15:8]};
                end
                ram_busy <= 0;
            end

            if (rd_valid && !rd_ready) begin
                case (state)
                    STATE_CMD: begin
                        cmd                <= rd_data[9:8];
                        ram.address[21:15] <= rd_data[6:0];
                        state              <= STATE_ADDR;
                        rd_ready           <= 1;
                    end
                    STATE_ADDR: begin
                        ram.address[14:7] <= rd_data[15:8];
                        ram.address[6:0]  <= rd_data[7:1];
                        reg_addr          <= rd_data[3:0];
                        state             <= STATE_DATA;
                        rd_ready          <= 1;
                        word_cnt          <= '0;
                        ram_busy          <= 0;
                    end
                    STATE_DATA: begin
                        if (cmd == CMD_WRITE_REG) begin
                            if (word_cnt == 0) begin
                                wr_reg[15:0] <= {rd_data[7:0], rd_data[15:8]};
                            end else begin
                                wr_reg[31:16] <= {rd_data[7:0], rd_data[15:8]};
                                wr_reg_changed <= !wr_reg_changed;
                                wr_reg_addr <= reg_addr;
                                state <= STATE_IDLE;
                            end

                            rd_ready <= 1;
                            word_cnt <= word_cnt + 1;
                        end else if (cmd == CMD_WRITE_MEM) begin
                            if (!ram_busy) begin
                                ram.data_write <= {rd_data[7:0], rd_data[15:8]};
                                ram.req <= 1;
                                ram_busy <= 1;
                                rd_ready <= 1;
                            end
                        end
                    end
                    default;
                endcase
            end

            if (state == STATE_DATA && wr_valid && !wr_ready) begin
                if (cmd == CMD_READ_REG) begin
                    if (reg_addr == 4'd1) begin
                        got_reg <= ev_reg;
                        wr_data <= (word_cnt == 0) ? {ev_reg[7:0], ev_reg[15:8]} : {got_reg[23:16], got_reg[31:24]};
                    end else if (reg_addr == 4'd2) begin
                        wr_data <= (word_cnt == 0) ? {VERSION[7:0], VERSION[15:8]} : 16'd0;
                    end

                    wr_ready <= 1;
                    word_cnt <= word_cnt + 1;

                    if (word_cnt == 1) begin
                        state <= STATE_IDLE;
                    end
                end else if (cmd == CMD_READ_MEM) begin
                    if (!ram_busy) begin
                        ram.req  <= 1;
                        ram_busy <= 1;
                    end
                end
            end
        end
    end


`ifdef DEBUG
    logic [21:0] debug_ram_address = ram.address;
    logic [15:0] debug_ram_data_read = ram.data_read;
    logic [15:0] debug_ram_data_write = ram.data_write;
    logic [ 1:0] debug_state = state;
`endif
endmodule
