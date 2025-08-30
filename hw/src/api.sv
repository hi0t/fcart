module api (
    input logic clk,
    input logic reset,
    output logic [31:0] wr_reg,
    output logic [3:0] wr_reg_addr,
    output logic wr_reg_changed,

    sdram_bus.controller ram,

    input logic [7:0] rd_data,
    input logic rd_valid,
    output logic rd_ready,
    output logic [7:0] wr_data,
    input logic wr_valid,
    output logic wr_ready,
    input logic start
);
    localparam CMD_WRITE_MEM = 1;
    localparam CMD_WRITE_REG = 3;

    enum logic [1:0] {
        STATE_CMD,
        STATE_ADDR,
        STATE_DATA
    } state;

    logic [1:0] byte_cnt;
    logic [7:0] cmd;
    logic zero_addr;
    logic is_upper_nibble;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STATE_CMD;
            wr_reg_changed <= 0;
        end else begin
            rd_ready <= 0;
            ram.req  <= 0;

            if (start) begin
                state <= STATE_CMD;
            end

            if (!rd_ready && rd_valid) begin
                case (state)
                    STATE_CMD: begin
                        rd_ready <= 1;
                        cmd <= rd_data;
                        byte_cnt <= 0;
                        state <= STATE_ADDR;
                    end
                    STATE_ADDR: begin
                        rd_ready <= 1;
                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt == 2) begin
                            byte_cnt <= 0;
                            state <= STATE_DATA;
                        end

                        case (cmd)
                            CMD_WRITE_MEM: begin
                                case (byte_cnt)
                                    0: ram.address[21:15] <= rd_data[6:0];
                                    1: ram.address[14:7] <= rd_data;
                                    2: {ram.address[6:0], is_upper_nibble} <= rd_data;
                                endcase
                                if (byte_cnt == 2) zero_addr <= 1;
                            end
                            CMD_WRITE_REG: begin
                                if (byte_cnt == 2) wr_reg_addr <= rd_data[3:0];
                            end
                        endcase
                    end
                    STATE_DATA: begin
                        byte_cnt <= byte_cnt + 1;

                        case (cmd)
                            CMD_WRITE_MEM: begin
                                if (!ram.busy) begin
                                    rd_ready <= 1;

                                    if (is_upper_nibble) begin
                                        ram.we <= 1;
                                        ram.wm <= 2'b00;
                                        ram.data_write[15:8] <= rd_data;
                                        if (zero_addr) zero_addr <= 0;
                                        else ram.address <= ram.address + 1;
                                        ram.req <= 1;
                                    end else begin
                                        ram.data_write[7:0] <= rd_data;
                                    end
                                    is_upper_nibble <= !is_upper_nibble;
                                end
                            end
                            CMD_WRITE_REG: begin
                                rd_ready <= 1;

                                case (byte_cnt)
                                    0: wr_reg[7:0] <= rd_data;
                                    1: wr_reg[15:8] <= rd_data;
                                    2: wr_reg[23:16] <= rd_data;
                                    3: wr_reg[31:24] <= rd_data;
                                endcase
                                if (byte_cnt == 3) wr_reg_changed <= !wr_reg_changed;
                            end
                        endcase
                    end
                    default;
                endcase
            end
        end
    end

    // Verilator lint_off UNUSED
    logic debug_ram_busy = ram.busy;
    logic [21:0] debug_ram_address = ram.address;
    logic [15:0] debug_ram_data = ram.data_write;
    logic [1:0] debug_state = state;
    // Verilator lint_on UNUSED
endmodule
