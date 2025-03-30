module qspi (
    // QSPI signals
    input logic clk,
    input logic ncs,
    inout wire [3:0] io,

    // QSPI interface
    qspi_bus.slave bus
);
    enum bit [1:0] {
        IDLE,
        COMMAND,
        DATA_READ,
        DATA_WRITE
    } state;

    logic [3:0] data_tx;
    logic bit_cnt;
    assign io = (state == DATA_WRITE) ? data_tx : 'z;
    assign data_tx = (bit_cnt == 0) ? bus.data_write[7:4] : bus.data_write[3:0];

    always_ff @(posedge clk or posedge ncs) begin
        bus.cmd_valid  <= 0;
        bus.data_valid <= 0;
        bus.write_done <= 0;

        if (ncs) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    state <= COMMAND;
                    bus.cmd[7:4] <= io;
                end
                COMMAND: begin
                    state <= DATA_READ;
                    bus.cmd[3:0] <= io;
                    bus.cmd_valid <= 1;
                    bit_cnt <= 0;
                end
                DATA_READ: begin
                    if (bus.we) begin
                        state <= DATA_WRITE;
                    end else begin
                        if (bit_cnt == 0) begin
                            bus.data_read[7:4] <= io;
                        end else begin
                            bus.data_read[3:0] <= io;
                            bus.data_valid <= 1;
                        end
                    end
                    bit_cnt <= bit_cnt + 1;
                end
                DATA_WRITE: begin
                    bus.write_done <= (bit_cnt == 0);
                    bit_cnt <= bit_cnt + 1;
                end
            endcase
        end
    end
endmodule
