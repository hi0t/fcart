module api (
    input  logic clk,
    input  logic reset,
    output logic loading,

    sdram_bus.master   sdram,
    bidir_bus.consumer bus
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
            bus.rd_en <= 0;

            if (bus.closed && bus.rd_empty) begin
                state <= STATE_CMD;
            end

            case (state)
                STATE_CMD: begin
                    if (!bus.rd_empty) begin
                        cmd <= bus.rd_data;
                        bus.rd_en <= 1;
                        byte_cnt <= 0;

                        case (bus.rd_data)
                            2:       loading <= 0;
                            default: state <= STATE_ADDR;
                        endcase
                    end
                end
                STATE_ADDR: begin
                    if (!bus.rd_empty) begin
                        case (byte_cnt)
                            0: sdram.address[21:15] <= bus.rd_data[6:0];
                            1: sdram.address[14:7] <= bus.rd_data;
                            2: begin
                                {sdram.address[6:0], high_byte} <= bus.rd_data;
                                zero_addr <= 1;
                                state <= STATE_DATA;
                            end
                        endcase
                        byte_cnt  <= byte_cnt + 1;
                        bus.rd_en <= 1;
                    end
                end
                STATE_DATA: begin
                    sdram.req <= sdram.busy;
                    if (!bus.rd_empty) begin
                        case (cmd)
                            1: begin
                                loading <= 1;
                                if (high_byte) begin
                                    sdram.we <= 1;
                                    sdram.req <= 1;
                                    sdram.data_write[15:8] <= bus.rd_data;
                                    if (zero_addr) zero_addr <= 0;
                                    else sdram.address <= sdram.address + 1;
                                end else begin
                                    sdram.data_write[7:0] <= bus.rd_data;
                                end
                                high_byte <= !high_byte;
                            end
                        endcase
                        bus.rd_en <= 1;
                    end
                end
                default;
            endcase
        end
    end
endmodule
