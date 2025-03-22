module qspi (
    // QSPI signals
    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io,

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
    assign qspi_io = (state == DATA_WRITE) ? data_tx : 'z;
    assign data_tx = (bit_cnt == 0) ? bus.data_write[7:4] : bus.data_write[3:0];

    always_ff @(posedge qspi_clk) begin
        if (qspi_ncs) begin
            state <= IDLE;
        end

        bus.cmd_ready  <= 0;
        bus.data_ready <= 0;
        bus.can_write  <= 1;

        case (state)
            IDLE: begin
                if (!qspi_ncs) begin
                    state <= COMMAND;
                    bus.cmd[7:4] <= qspi_io;
                end
            end
            COMMAND: begin
                state <= DATA_READ;
                bus.cmd[3:0] <= qspi_io;
                bus.cmd_ready <= 1;
                bit_cnt <= 0;
            end
            DATA_READ: begin
                if (bus.we) begin
                    state <= DATA_WRITE;
                    bit_cnt <= 0;
                    bus.can_write <= 0;
                end else begin
                    if (bit_cnt == 0) begin
                        bus.data_read[7:4] <= qspi_io;
                    end else begin
                        bus.data_read[3:0] <= qspi_io;
                        bus.data_ready <= 1;
                    end
                    bit_cnt <= bit_cnt + 1;
                end
            end
            DATA_WRITE: begin
                bus.can_write <= (bit_cnt == 0);
                bit_cnt <= bit_cnt + 1;
            end
        endcase
    end
endmodule
