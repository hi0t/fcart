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
    output logic [7:0] wr_data,
    input logic wr_ready,
    input logic start
);
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
    logic [22:0] addr;
    logic [31:0] got_reg;

    assign fpga_irq = (got_reg != ev_reg);

    always_ff @(posedge clk) begin
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
                        byte_cnt <= byte_cnt + 2'd1;

                        case (byte_cnt)
                            2'd0: addr[22:16] <= rd_data[6:0];
                            2'd1: addr[15:8] <= rd_data;
                            2'd2: addr[7:0] <= rd_data;
                            default;
                        endcase

                        if (byte_cnt == 2'd2) begin
                            byte_cnt <= 2'd0;
                            state <= STATE_DATA;
                        end
                    end

                    STATE_DATA: begin
                        if (cmd == CMD_WRITE_REG) begin
                            byte_cnt <= byte_cnt + 2'd1;

                            case (byte_cnt)
                                2'd0: wr_reg[7:0] <= rd_data;
                                2'd1: wr_reg[15:8] <= rd_data;
                                2'd2: wr_reg[23:16] <= rd_data;
                                2'd3: wr_reg[31:24] <= rd_data;
                            endcase

                            if (byte_cnt == 2'd3) begin
                                state <= STATE_IDLE;
                                wr_reg_addr <= addr[3:0];
                                wr_reg_changed <= !wr_reg_changed;
                            end
                        end
                    end

                    default;
                endcase
            end

            if (wr_ready && state == STATE_DATA) begin
                if (cmd == CMD_READ_REG) begin
                    byte_cnt <= byte_cnt + 2'd1;

                    case (addr[3:0])
                        4'd1: begin
                            got_reg <= ev_reg;
                            case (byte_cnt)
                                2'd0: wr_data <= ev_reg[7:0];
                                2'd1: wr_data <= ev_reg[15:8];
                                2'd2: wr_data <= ev_reg[23:16];
                                2'd3: wr_data <= ev_reg[31:24];
                            endcase
                        end
                        default: wr_data <= 8'd0;
                    endcase

                    if (byte_cnt == 2'd3) state <= STATE_IDLE;
                end
            end
        end
    end


    logic wr_fifo_empty;
    logic [7:0] wr_fifo_data;
    logic wr_byte;
    logic first_byte;
    fifo wr_fifo (
        .clk(clk),
        .reset(start),
        .wr_data(rd_data),
        .wr_en(rd_valid && state == STATE_DATA && cmd == CMD_WRITE_MEM),
        .full(),
        .rd_data(wr_fifo_data),
        .rd_en(!wr_fifo_empty && ram.req == ram.ack),
        .empty(wr_fifo_empty)
    );

    always_ff @(posedge clk) begin
        if (start) begin
            wr_byte <= 1'b0;
            first_byte <= 1'b1;
        end

        if (!wr_fifo_empty && ram.req == ram.ack) begin
            if (wr_byte) begin
                ram.data_write[15:8] <= wr_fifo_data;

                ram.we <= 1'b1;
                ram.wm <= 2'b00;
                ram.req <= !ram.req;

                if (first_byte) begin
                    ram.address <= addr[22:1];
                    first_byte  <= 1'b0;
                end else begin
                    ram.address <= ram.address + 1'd1;
                end
            end else ram.data_write[7:0] <= wr_fifo_data;
            wr_byte <= !wr_byte;
        end
    end

`ifdef DEBUG
    logic debug_ram_busy = ram.req != ram.ack;
    logic [21:0] debug_ram_address = ram.address;
    logic [15:0] debug_ram_data = ram.data_write;
    logic [1:0] debug_state = state;
`endif
endmodule
