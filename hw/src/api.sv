module api (
    input  logic clk,
    input  logic reset,
    output logic fpga_irq,

    output logic [31:0] wr_reg,
    output logic [3:0] wr_reg_addr,
    output logic wr_reg_changed,
    input logic [31:0] ev_reg,

    sdram_bus.controller ram,

    input logic [7:0] rd_data,
    input logic rd_valid,
    output logic rd_ready,
    output logic [7:0] wr_data,
    input logic wr_valid,
    output logic wr_ready,
    input logic start
);
    localparam CMD_WRITE_MEM = 8'd1;
    localparam CMD_READ_REG = 8'd2;
    localparam CMD_WRITE_REG = 8'd3;

    enum logic [1:0] {
        STATE_CMD,
        STATE_ADDR,
        STATE_DATA,
        STATE_DONE
    } state;

    logic [1:0] byte_cnt;
    logic [7:0] cmd;
    logic is_upper_nibble;
    logic write_in_progress;
    logic [3:0] rd_reg_addr;
    logic [31:0] got_reg;

    assign fpga_irq = (got_reg != ev_reg);

    always_ff @(posedge clk) begin
        if (reset) begin
            ram.req <= 0;
            ram.we <= 0;
            state <= STATE_CMD;
            wr_reg_changed <= 0;
            got_reg <= '0;
        end else begin
            rd_ready <= 0;
            wr_ready <= 0;

            if (start) begin
                state <= STATE_CMD;
            end else if (!rd_ready && rd_valid) begin
                case (state)
                    STATE_CMD: begin
                        rd_ready <= 1;
                        cmd <= rd_data;
                        byte_cnt <= '0;
                        state <= STATE_ADDR;
                    end

                    STATE_ADDR: begin
                        rd_ready <= 1;
                        byte_cnt <= byte_cnt + 2'd1;

                        if (byte_cnt == 2'd2) begin
                            byte_cnt <= '0;
                            state <= STATE_DATA;
                        end

                        case (cmd)
                            CMD_WRITE_MEM: begin
                                case (byte_cnt)
                                    2'd0: ram.address[21:15] <= rd_data[6:0];
                                    2'd1: ram.address[14:7] <= rd_data;
                                    2'd2: {ram.address[6:0], is_upper_nibble} <= rd_data;
                                    default;
                                endcase
                                write_in_progress <= 0;
                            end
                            CMD_READ_REG: begin
                                if (byte_cnt == 2'd2) rd_reg_addr <= rd_data[3:0];
                            end
                            CMD_WRITE_REG: begin
                                if (byte_cnt == 2'd2) wr_reg_addr <= rd_data[3:0];
                            end
                            default;
                        endcase
                    end

                    STATE_DATA: begin
                        case (cmd)
                            CMD_WRITE_MEM: begin
                                if (is_upper_nibble) begin
                                    if (!write_in_progress && ram.req == ram.ack) begin
                                        ram.we <= 1;
                                        ram.wm <= 2'b00;
                                        ram.data_write[15:8] <= rd_data;
                                        ram.req <= !ram.req;
                                        write_in_progress <= 1;
                                    end else if (ram.req == ram.ack) begin
                                        rd_ready <= 1;
                                        is_upper_nibble <= 0;
                                        ram.address <= ram.address + 1;
                                        write_in_progress <= 0;
                                    end
                                end else begin
                                    rd_ready <= 1;
                                    ram.data_write[7:0] <= rd_data;
                                    is_upper_nibble <= 1;
                                end
                            end

                            CMD_WRITE_REG: begin
                                rd_ready <= 1;
                                byte_cnt <= byte_cnt + 2'd1;

                                case (byte_cnt)
                                    2'd0: wr_reg[7:0] <= rd_data;
                                    2'd1: wr_reg[15:8] <= rd_data;
                                    2'd2: wr_reg[23:16] <= rd_data;
                                    2'd3: wr_reg[31:24] <= rd_data;
                                endcase
                                if (byte_cnt == 2'd3) begin
                                    state <= STATE_DONE;
                                    wr_reg_changed <= !wr_reg_changed;
                                end
                            end
                            default;
                        endcase
                    end
                    default;
                endcase
            end else if (!wr_ready && wr_valid) begin
                if (state == STATE_DATA) begin
                    if (cmd == CMD_READ_REG) begin
                        wr_ready <= 1;
                        byte_cnt <= byte_cnt + 2'd1;

                        case (rd_reg_addr)
                            1: begin
                                got_reg <= ev_reg;

                                case (byte_cnt)
                                    2'd0: wr_data <= ev_reg[7:0];
                                    2'd1: wr_data <= ev_reg[15:8];
                                    2'd2: wr_data <= ev_reg[23:16];
                                    2'd3: wr_data <= ev_reg[31:24];
                                endcase
                                if (byte_cnt == 2'd3) state <= STATE_DONE;
                            end
                        endcase
                    end
                end
            end
        end
    end

`ifdef DEBUG
    logic debug_ram_busy = ram.req != ram.ack;
    logic [21:0] debug_ram_address = ram.address;
    logic [15:0] debug_ram_data = ram.data_write;
    logic [1:0] debug_state = state;
`endif
endmodule
