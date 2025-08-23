module api (
    input logic clk,
    input logic reset,
    output logic [23:0] map_ctrl,
    output logic map_ctrl_req,
    input logic map_ctrl_ack,

    sdram_bus.controller ram,
    bidir_bus.consumer   qspi_bus
);
    localparam CMD_WRITE = 1;
    localparam CMD_LAUNCH = 2;

    enum logic [1:0] {
        STATE_CMD,
        STATE_ADDR,
        STATE_DATA
    } state;

    logic [1:0] byte_cnt;
    logic [7:0] cmd;
    logic high_byte, zero_addr;
    logic [1:0] map_ctrl_ack_sync;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STATE_CMD;
            map_ctrl_req <= 0;
        end else begin
            qspi_bus.rd_ready <= 0;
            ram.req <= 0;

            if (qspi_bus.closed && !qspi_bus.rd_valid) begin
                state <= STATE_CMD;
            end

            map_ctrl_ack_sync <= {map_ctrl_ack_sync[0], map_ctrl_ack};

            if (!qspi_bus.rd_ready && qspi_bus.rd_valid) begin
                case (state)
                    STATE_CMD: begin
                        qspi_bus.rd_ready <= 1;
                        cmd <= qspi_bus.rd_data;
                        byte_cnt <= 0;
                        state <= STATE_ADDR;
                    end
                    STATE_ADDR: begin
                        qspi_bus.rd_ready <= 1;
                        byte_cnt <= byte_cnt + 1;

                        case (cmd)
                            CMD_WRITE: begin
                                case (byte_cnt)
                                    0: ram.address[21:15] <= qspi_bus.rd_data[6:0];
                                    1: ram.address[14:7] <= qspi_bus.rd_data;
                                    2: {ram.address[6:0], high_byte} <= qspi_bus.rd_data;
                                endcase
                                if (byte_cnt == 2) begin
                                    zero_addr <= 1;
                                    state <= STATE_DATA;
                                end
                            end
                            CMD_LAUNCH: begin
                                case (byte_cnt)
                                    0: map_ctrl[23:16] <= qspi_bus.rd_data;
                                    1: map_ctrl[15:8] <= qspi_bus.rd_data;
                                    2: map_ctrl[7:0] <= qspi_bus.rd_data;
                                endcase
                                if ((byte_cnt == 2) && (map_ctrl_req == map_ctrl_ack_sync[1])) map_ctrl_req <= !map_ctrl_req;
                            end
                        endcase
                    end
                    STATE_DATA: begin
                        if (!ram.busy) begin
                            qspi_bus.rd_ready <= 1;

                            case (cmd)
                                CMD_WRITE: begin
                                    if (high_byte) begin
                                        ram.we <= 1;
                                        ram.wm <= 2'b00;
                                        ram.data_write[15:8] <= qspi_bus.rd_data;
                                        if (zero_addr) zero_addr <= 0;
                                        else ram.address <= ram.address + 1;
                                        ram.req <= 1;
                                    end else begin
                                        ram.data_write[7:0] <= qspi_bus.rd_data;
                                    end
                                    high_byte <= !high_byte;
                                end
                            endcase
                        end
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
    logic debug_rd_valid = qspi_bus.rd_valid;
    logic debug_rd_ready = qspi_bus.rd_ready;
    logic [7:0] debug_rd_data = qspi_bus.rd_data;
    // Verilator lint_on UNUSED
endmodule
