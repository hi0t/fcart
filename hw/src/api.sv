module api (
    input logic clk,

    sdram_bus.master sdram,
    qspi_bus.master  qspi
);
    bit [1:0] byte_cnt;
    bit [7:0] cmd;
    bit high_byte;

    always_ff @(posedge clk) begin
        if (qspi.cmd_ready) begin
            cmd <= qspi.cmd;
            byte_cnt <= 0;
        end

        if (qspi.data_ready) begin
            case (cmd)
                1: begin
                    if (byte_cnt < 3) byte_cnt <= byte_cnt + 1;

                    if (byte_cnt == 0) sdram.address[21:15] <= qspi.data_read[6:0];
                    else if (byte_cnt == 1) sdram.address[14:7] <= qspi.data_read;
                    else if (byte_cnt == 2) {sdram.address[6:0], high_byte} <= qspi.data_read;
                    else begin
                        sdram.we <= 1;
                        if (high_byte) begin
                            sdram.data_write[15:8] <= qspi.data_read;
                            sdram.req <= !sdram.req;
                            sdram.address <= sdram.address + 1;
                        end else begin
                            sdram.data_write[7:0] <= qspi.data_read;
                        end
                        high_byte <= !high_byte;
                    end
                end
            endcase
        end
    end

endmodule
