module qspi (
    // QSPI signals
    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io,

    // QSPI interface
    input logic clk,  // System clock
    output logic [7:0] cmd,  // Command read from QSPI
    output logic cmd_ready,  // Pulse to indicate command is ready
    output logic [7:0] data_read,  // Word read from QSPI
    input logic [7:0] data_write,  // Word to write to QSPI
    output logic data_ready,  // Pulse to indicate data is ready
    input logic we  // Start write
);
    enum bit [1:0] {
        IDLE,
        COMMAND,
        DATA
    } state;

    bit bit_cnt;
    logic [3:0] data_tx;
    bit cmd_req, cmd_ack, data_req, data_ack;
    assign qspi_io = we ? data_tx : 'z;
    assign cmd_ready = (cmd_req != cmd_ack);
    assign data_ready = (data_req != data_ack);

    always_ff @(posedge clk) begin
        cmd_ack  <= cmd_req;
        data_ack <= data_req;
    end

    always_ff @(posedge qspi_clk) begin
        if (qspi_ncs) begin
            state <= IDLE;
        end
        case (state)
            IDLE: begin
                if (!qspi_ncs) begin
                    state <= COMMAND;
                    cmd[7:4] <= qspi_io;
                end
            end
            COMMAND: begin
                state <= DATA;
                cmd[3:0] <= qspi_io;
                cmd_req <= !cmd_req;
                bit_cnt <= 0;
            end
            DATA: begin
                if (we) begin
                    if (bit_cnt == 0) begin
                        data_tx <= data_write[7:4];
                    end else begin
                        data_tx  <= data_write[3:0];
                        data_req <= !data_req;
                    end
                end else begin
                    if (bit_cnt == 0) begin
                        data_read[7:4] <= qspi_io;
                    end else begin
                        data_read[3:0] <= qspi_io;
                        data_req <= !data_req;
                    end
                end
                bit_cnt <= bit_cnt + 1;
            end
            default;
        endcase
    end
endmodule
