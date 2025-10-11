module qspi (
    input logic clk,
    input logic async_reset,

    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io,

    output logic [7:0] rd_data,
    output logic rd_valid,
    input logic [7:0] wr_data,
    output logic wr_ready,
    output logic start
);
    enum logic [1:0] {
        STATE_CMD,
        STATE_RECEIVE,
        STATE_SEND
    } state;

    logic qspi_reset;
    logic [2:0] cnt;
    logic [3:0] upper_nibble;
    logic [2:0] start_sync, rd_sync, wr_sync;
    logic rx_done, tx_ready;
    logic [7:0] io_out;
    logic has_resp;
    logic rx_sw;

    assign qspi_reset = async_reset || qspi_ncs;

    // RX logic
    always_ff @(posedge qspi_clk or posedge qspi_reset) begin
        if (qspi_reset) begin
            state <= STATE_CMD;
            cnt   <= 3'd0;
        end else begin
            cnt <= cnt + 3'd1;
            rx_done <= 1'b0;

            if (cnt[0] == 1'b0) upper_nibble <= qspi_io;
            else if (state != STATE_SEND) begin
                rd_data <= {upper_nibble, qspi_io};
                rx_done <= 1'b1;
            end

            if (state == STATE_CMD) begin
                if (cnt == 3'd1) begin
                    has_resp <= (qspi_io[0] == 1'b0);  // Detect if the command expects a response
                    cnt <= 3'd0;
                    state <= STATE_RECEIVE;
                end
            end else if (state == STATE_RECEIVE && has_resp && cnt == 3'd5) begin  // Capture 24-bit address
                state <= STATE_SEND;
            end
        end
    end

    // TX logic
    assign qspi_io = (state == STATE_SEND) ? (rx_sw ? io_out[7:4] : io_out[3:0]) : 4'bz;
    always_ff @(negedge qspi_clk) begin
        rx_sw <= 1'b0;
        if (state == STATE_SEND && !rx_sw) begin
            io_out <= wr_data;
            rx_sw  <= 1'b1;
        end
        tx_ready <= (state == STATE_SEND && cnt[0] == 1'b0);
    end

    // QSPI clock domain to system clock domain synchronization
    assign start = (start_sync[2:1] == 2'b10);
    assign rd_valid = (rd_sync[2:1] == 2'b01);
    assign wr_ready = (wr_sync[2:1] == 2'b01);
    always_ff @(posedge clk) begin
        start_sync <= {start_sync[1:0], qspi_ncs};
        rd_sync    <= {rd_sync[1:0], rx_done};
        wr_sync    <= {wr_sync[1:0], tx_ready};
    end
endmodule
