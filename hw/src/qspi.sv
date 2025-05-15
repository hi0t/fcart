module qspi (
    input logic clk,
    input logic reset,

    bidir_bus.provider bus,

    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io
);
    enum logic [1:0] {
        STATE_CMD,
        STATE_RECEIVE,
        STATE_SEND
    } state;

    logic qspi_reset;
    logic fifo_reset;
    logic tx_empty;
    logic [7:0] rx_data, tx_data;
    logic rx_en, tx_en;
    logic [3:0] high_bits;
    logic [3:0] io_out;
    logic first_cycle;
    logic [1:0] ncs_sync;

    fifo #(
        .DEPTH(16)
    ) fifo_rx (
        .wr_clk(qspi_clk),
        .wr_reset(fifo_reset),
        .wr_data(rx_data),
        .wr_en(rx_en),
        .full(),

        .rd_clk(clk),
        .rd_reset(reset),
        .rd_data(bus.rd_data),
        .rd_en(bus.rd_en || bus.wr_en),  // purge dummy bytes if writing followed
        .empty(bus.rd_empty)
    );

    fifo #(
        .DEPTH(8)
    ) fifo_tx (
        .wr_clk(clk),
        .wr_reset(reset),
        .wr_data(bus.wr_data),
        .wr_en(bus.wr_en),
        .full(bus.wr_full),

        .rd_clk(qspi_clk),
        .rd_reset(fifo_reset),
        .rd_data(tx_data),
        .rd_en(tx_en),
        .empty(tx_empty)
    );

    // RX logic
    assign qspi_reset = reset || qspi_ncs;
    assign rx_en = !first_cycle && (state == STATE_CMD || state == STATE_RECEIVE);
    assign rx_data = {high_bits, qspi_io};
    always_ff @(posedge qspi_clk or posedge qspi_reset) begin
        if (qspi_reset) begin
            first_cycle <= 1;
            state       <= STATE_CMD;
        end else begin
            fifo_reset  <= 0;
            first_cycle <= !first_cycle;

            if (state == STATE_CMD || state == STATE_RECEIVE) begin
                if (first_cycle) begin
                    high_bits <= qspi_io;
                end else begin
                    if (state == STATE_CMD) begin
                        // The zero command resets the FIFO
                        if (rx_data == '0) fifo_reset <= 1;
                        state <= STATE_RECEIVE;
                    end
                    if (!tx_empty) state <= STATE_SEND;
                end
            end
        end
    end

    // TX logic
    assign tx_en   = !first_cycle && (state == STATE_SEND);
    assign qspi_io = (state == STATE_SEND) ? io_out : 'z;
    always_ff @(negedge qspi_clk) begin
        if (state == STATE_SEND) begin
            if (first_cycle) io_out <= tx_data[7:4];
            else io_out <= tx_data[3:0];
        end
    end

    // Notify the consumer of the completion of the transfer
    assign bus.closed = ncs_sync[1];
    always_ff @(posedge clk) begin
        ncs_sync <= {ncs_sync[0], qspi_ncs};
    end
endmodule
