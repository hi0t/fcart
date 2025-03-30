module api (
    input  logic clk,
    output logic loading,

    sdram_bus.master sdram,
    qspi_bus.master  qspi
);
    bit [1:0] byte_cnt;
    logic [7:0] cmd;
    logic high_byte;
    logic prev_cmd_valid, prev_data_valid;

    always_ff @(posedge clk) begin
        prev_cmd_valid  <= prev_cmd_valid & qspi.cmd_valid;
        prev_data_valid <= prev_data_valid & qspi.data_valid;

        if (!prev_cmd_valid && qspi.cmd_valid) begin
            cmd <= qspi.cmd;
            byte_cnt <= 0;
        end

        if (!prev_data_valid && qspi.data_valid) begin
            case (cmd)
                1: begin
                    loading  <= 1;
                    byte_cnt <= byte_cnt + 1;

                    if (byte_cnt == 0) sdram.address[21:15] <= qspi.data_read[6:0];
                    else if (byte_cnt == 1) sdram.address[14:7] <= qspi.data_read;
                    else if (byte_cnt == 2) {sdram.address[6:0], high_byte} <= qspi.data_read;
                end
                2: begin
                    if (high_byte) begin
                        sdram.we <= 1;
                        sdram.data_write[15:8] <= qspi.data_read;
                        sdram.req <= !sdram.req;
                        sdram.address <= sdram.address + 1;
                    end else begin
                        sdram.data_write[7:0] <= qspi.data_read;
                    end
                    high_byte <= !high_byte;
                end
                3: loading <= 0;
            endcase
        end
    end

endmodule
