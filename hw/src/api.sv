module api (
    input  logic clk,
    input  logic reset,
    output logic loading,

    sdram_bus.controller ram,
    bidir_bus.consumer   bus
);
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
                        cmd <= bus.rd_data;
                        byte_cnt <= 0;
                        bus.rd_ready <= 1;

                        case (bus.rd_data)
                            2:       loading <= 0;
                            default: state <= STATE_ADDR;
                        endcase
                    end
                    STATE_ADDR: begin
                        byte_cnt <= byte_cnt + 1;
                        bus.rd_ready <= 1;

                        case (byte_cnt)
                            0: ram.address[21:15] <= bus.rd_data[6:0];
                            1: ram.address[14:7] <= bus.rd_data;
                            2: begin
                                {ram.address[6:0], high_byte} <= bus.rd_data;
                                zero_addr <= 1;
                                state <= STATE_DATA;
                                loading <= 1;
                            end
                        endcase
                    end
                    STATE_DATA: begin
                        if (!ram.busy) begin
                            bus.rd_ready <= 1;

                            case (cmd)
                                1: begin
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
