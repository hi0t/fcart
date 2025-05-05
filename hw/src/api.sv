module api (
    input  logic clk,
    output logic loading,

    sdram_bus.master sdram,
    spi_bus.master   spi
);
    enum bit [1:0] {
        STATE_CMD,
        STATE_ADDR,
        STATE_DATA
    } state = STATE_CMD;

    bit [1:0] byte_cnt;
    logic [7:0] cmd;
    logic high_byte, zero_addr;

    always_ff @(posedge clk) begin
        if (spi.transm_end) begin
            state <= STATE_CMD;
        end

        case (state)
            STATE_CMD: begin
                if (spi.read_valid) begin
                    cmd <= spi.read;
                    byte_cnt <= 0;

                    case (spi.read)
                        2:       loading <= 0;
                        default: state <= STATE_ADDR;
                    endcase
                end
            end
            STATE_ADDR: begin
                if (spi.read_valid) begin
                    case (byte_cnt)
                        0: sdram.address[21:15] <= spi.read[6:0];
                        1: sdram.address[14:7] <= spi.read;
                        2: begin
                            {sdram.address[6:0], high_byte} <= spi.read;
                            zero_addr <= 1;
                            state <= STATE_DATA;
                        end
                    endcase
                    byte_cnt <= byte_cnt + 1'd1;
                end
            end
            STATE_DATA: begin
                sdram.req <= 0;
                if (spi.read_valid) begin
                    case (cmd)
                        1: begin
                            loading <= 1;
                            if (high_byte) begin
                                sdram.we <= 1;
                                sdram.req <= 1;
                                sdram.data_write[15:8] <= spi.read;
                                if (zero_addr) zero_addr <= 0;
                                else sdram.address <= sdram.address + 1'd1;
                            end else begin
                                sdram.data_write[7:0] <= spi.read;
                            end
                            high_byte <= !high_byte;
                        end
                    endcase
                end
            end
            default;
        endcase
    end

endmodule
