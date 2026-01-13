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

    input logic [7:0] rd_data,
    input logic rd_valid,
    output logic [7:0] wr_data,
    input logic wr_valid,
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

    logic [1:0] byte_cnt;
    logic [7:0] cmd;
    logic [31:0] got_reg;
    logic [7:0] wr_buf;
    logic [7:0] rd_buf;
    logic [3:0] reg_addr;
    logic first_req;

    assign fpga_irq = (got_reg != ev_reg);

    always_ff @(posedge clk) begin
        ram.req <= 1'b0;
        ram_refresh <= 1'b0;

        if (reset) begin
            state <= STATE_IDLE;
        end else begin
            if (start) begin
                state <= STATE_CMD;
            end

            if (rd_valid) begin
                case (state)
                    STATE_CMD: begin
                        cmd <= rd_data;
                        byte_cnt <= '0;
                        state <= STATE_ADDR;
                    end

                    STATE_ADDR: begin
                        byte_cnt  <= byte_cnt + 2'd1;
                        first_req <= 1'b1;

                        case (byte_cnt)
                            2'd0: ram.address[21:15] <= rd_data[6:0];
                            2'd1: ram.address[14:7] <= rd_data;
                            2'd2: ram.address[6:0] <= rd_data[7:1];
                            default;
                        endcase

                        if (byte_cnt == 2'd0) ram_refresh <= 1'b1;

                        if (byte_cnt == 2'd2) begin
                            reg_addr <= rd_data[3:0];

                            if (cmd == CMD_READ_MEM) begin
                                ram.we  <= 1'b0;
                                ram.req <= 1'b1;
                            end

                            byte_cnt <= 2'd0;
                            state <= STATE_DATA;
                        end
                    end

                    STATE_DATA: begin
                        byte_cnt <= byte_cnt + 2'd1;

                        if (cmd == CMD_WRITE_REG) begin
                            case (byte_cnt)
                                2'd0: wr_reg[7:0] <= rd_data;
                                2'd1: wr_reg[15:8] <= rd_data;
                                2'd2: wr_reg[23:16] <= rd_data;
                                2'd3: wr_reg[31:24] <= rd_data;
                            endcase

                            if (byte_cnt == 2'd3) begin
                                state <= STATE_IDLE;
                                wr_reg_addr <= reg_addr;
                                wr_reg_changed <= !wr_reg_changed;
                            end
                        end else if (cmd == CMD_WRITE_MEM) begin
                            case (byte_cnt[0])
                                1'b0: begin
                                    wr_buf <= rd_data;
                                    ram_refresh <= 1'b1;
                                end
                                1'b1: begin
                                    ram.data_write <= {rd_data, wr_buf};
                                    ram.we <= 1'b1;
                                    ram.wm <= 2'b00;
                                    ram.req <= 1'b1;

                                    if (first_req) first_req <= 1'b0;
                                    else ram.address <= ram.address + 1'd1;
                                end
                            endcase
                        end
                    end

                    default;
                endcase
            end

            if (wr_valid && state == STATE_DATA) begin
                byte_cnt <= byte_cnt + 2'd1;

                if (cmd == CMD_READ_REG) begin
                    case (reg_addr)
                        4'd1: begin
                            got_reg <= ev_reg;
                            case (byte_cnt)
                                2'd0: wr_data <= ev_reg[7:0];
                                2'd1: wr_data <= ev_reg[15:8];
                                2'd2: wr_data <= ev_reg[23:16];
                                2'd3: wr_data <= ev_reg[31:24];
                            endcase
                        end
                        4'd2: begin
                            case (byte_cnt)
                                2'd0: wr_data <= VERSION[7:0];
                                2'd1: wr_data <= VERSION[15:8];
                                2'd2: wr_data <= 8'd0;
                                2'd3: wr_data <= 8'd0;
                            endcase
                        end
                        default: wr_data <= 8'd0;
                    endcase
                    if (byte_cnt == 2'd3) state <= STATE_IDLE;
                end else if (cmd == CMD_READ_MEM) begin
                    case (byte_cnt[0])
                        1'b0: begin
                            wr_data <= ram.data_read[7:0];
                            rd_buf <= ram.data_read[15:8];
                            ram.req <= 1'b1;
                            ram.address <= ram.address + 1'd1;
                        end
                        1'b1: begin
                            wr_data <= rd_buf;
                            ram_refresh <= 1'b1;
                        end
                    endcase
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
