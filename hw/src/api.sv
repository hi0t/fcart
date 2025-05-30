module api (
    input logic clk,
    input logic reset,
    output logic loading,
    output logic [7:0] ppu_off,
    output logic mirroring,

    sdram_bus.controller ram,
    bidir_bus.consumer   bus
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

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STATE_CMD;
        end else begin
            bus.rd_ready <= 0;
            ram.req <= 0;

            if (bus.closed && !bus.rd_valid) begin
                state <= STATE_CMD;
            end

            if (!bus.rd_ready && bus.rd_valid) begin
                case (state)
                    STATE_CMD: begin
                        bus.rd_ready <= 1;
                        cmd <= bus.rd_data;
                        byte_cnt <= 0;
                        state <= STATE_ADDR;
                    end
                    STATE_ADDR: begin
                        bus.rd_ready <= 1;
                        byte_cnt <= byte_cnt + 1;

                        case (cmd)
                            CMD_WRITE: begin
                                case (byte_cnt)
                                    0: ram.address[21:15] <= bus.rd_data[6:0];
                                    1: ram.address[14:7] <= bus.rd_data;
                                    2: {ram.address[6:0], high_byte} <= bus.rd_data;
                                endcase
                                if (byte_cnt == 2) begin
                                    zero_addr <= 1;
                                    state <= STATE_DATA;
                                    loading <= 1;
                                end
                            end
                            CMD_LAUNCH: begin
                                case (byte_cnt)
                                    1: mirroring <= bus.rd_data[0];
                                    2: ppu_off <= bus.rd_data;
                                endcase
                                if (byte_cnt == 2) loading <= 0;
                            end
                        endcase
                    end
                    STATE_DATA: begin
                        if (!ram.busy) begin
                            bus.rd_ready <= 1;

                            case (cmd)
                                CMD_WRITE: begin
                                    if (high_byte) begin
                                        ram.we <= 1;
                                        ram.data_write[15:8] <= bus.rd_data;
                                        if (zero_addr) zero_addr <= 0;
                                        else ram.address <= ram.address + 1;
                                        ram.req <= 1;
                                    end else begin
                                        ram.data_write[7:0] <= bus.rd_data;
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
    logic debug_ram_req = ram.req;
    logic [21:0] debug_ram_address = ram.address;
    logic [15:0] debug_ram_data = ram.data_write;
    logic [1:0] debug_state = state;
    logic debug_rd_valid = bus.rd_valid;
    logic debug_rd_ready = bus.rd_ready;
    logic [7:0] debug_rd_data = bus.rd_data;
    // Verilator lint_on UNUSED
endmodule
