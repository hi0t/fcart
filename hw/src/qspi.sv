module qspi (
    input logic clk,
    input logic async_reset,

    output logic [7:0] rd_data,
    output logic rd_valid,
    input logic rd_ready,
    input logic [7:0] wr_data,
    output logic wr_valid,
    input logic wr_ready,
    output logic start,

    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io
);
    enum logic [1:0] {
        STATE_CMD,
        STATE_RECEIVE,
        STATE_SEND
    } state;

    logic qspi_reset, fifo_reset;
    logic rx_empty, tx_full;
    logic [7:0] rx_data, tx_data;
    logic rx_en, tx_en;
    logic [3:0] upper_nibble;
    logic [3:0] io_out;
    logic [2:0] cnt;
    logic [2:0] start_sync, reset_sync;
    logic has_resp;

    assign qspi_reset = async_reset || qspi_ncs;
    assign rd_valid   = !rx_empty;
    assign wr_valid   = !tx_full;

    fifo #(
        .DEPTH(16)
    ) fifo_rx (
        .wr_clk(qspi_clk),
        .wr_reset(fifo_reset),
        .wr_data(rx_data),
        .wr_en(rx_en),
        .full(),

        .rd_clk(clk),
        .rd_reset(fifo_reset),
        .rd_data(rd_data),
        .rd_en(rd_ready),
        .empty(rx_empty)
    );

    fifo #(
        .DEPTH(8)
    ) fifo_tx (
        .wr_clk(clk),
        .wr_reset(fifo_reset),
        .wr_data(wr_data),
        .wr_en(wr_ready),
        .full(tx_full),

        .rd_clk(qspi_clk),
        .rd_reset(fifo_reset),
        .rd_data(tx_data),
        .rd_en(tx_en),
        .empty()
    );

    // RX logic
    assign rx_en   = (cnt[0] == 1) && (state != STATE_SEND);
    assign rx_data = {upper_nibble, qspi_io};
    always_ff @(posedge qspi_clk or posedge qspi_reset) begin
        if (qspi_reset) begin
            cnt <= '0;
            state <= STATE_CMD;
            has_resp <= 0;
        end else begin
            cnt <= cnt + 1;
            if (cnt[0] == 0) upper_nibble <= qspi_io;

            if (state == STATE_CMD) begin
                if (cnt == 1) begin
                    has_resp <= (qspi_io[0] == 0);  // Detect if the command expects a response
                    cnt <= 0;
                    state <= STATE_RECEIVE;
                end
            end else if (state == STATE_RECEIVE) begin
                if (has_resp && cnt == 6) state <= STATE_SEND;
            end
        end
    end

    // TX logic
    assign tx_en   = (cnt[0] == 1) && (state == STATE_SEND);
    assign qspi_io = (state == STATE_SEND) ? io_out : 'z;
    always_ff @(negedge qspi_clk) begin
        if (state == STATE_SEND) begin
            if (cnt[0] == 0) io_out <= tx_data[7:4];
            else io_out <= tx_data[3:0];
        end
    end

    // Start detection
    assign start = (start_sync[2:1] == 2'b10);
    assign fifo_reset = (reset_sync[2:1] == 2'b10);
    always_ff @(posedge clk) begin
        start_sync <= {start_sync[1:0], qspi_ncs};
        reset_sync <= {reset_sync[1:0], qspi_ncs};
    end
endmodule
