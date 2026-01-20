module qspi (
    input logic clk,

    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io,

    output logic [15:0] rd_data,
    output logic rd_valid,
    input logic rd_ready,
    input logic [15:0] wr_data,
    output logic wr_valid,
    input logic wr_ready,
    output logic start
);
    enum logic [1:0] {
        STATE_CMD,
        STATE_RECEIVE,
        STATE_DUMMY,
        STATE_SEND
    } state;

    logic rx_empty, tx_full;
    logic [15:0] rx_data, tx_data;
    logic [11:0] rx_shift, tx_shift;
    logic rx_en, tx_en;
    logic [3:0] io_out;
    logic [2:0] cnt;
    logic [2:0] start_sync;
    logic has_resp;

    assign rd_valid = !rx_empty;
    assign wr_valid = (state == STATE_SEND) ? !tx_full : 0;

    fifo rx_fifo (
        .wr_clk(qspi_clk),
        .wr_reset(start),
        .wr_data(rx_data),
        .wr_en(rx_en),
        .full(),

        .rd_clk(clk),
        .rd_reset(start),
        .rd_data(rd_data),
        .rd_en(rd_ready),
        .empty(rx_empty)
    );

    fifo tx_fifo (
        .wr_clk(clk),
        .wr_reset(start),
        .wr_data(wr_data),
        .wr_en(wr_ready),
        .full(tx_full),

        .rd_clk(qspi_clk),
        .rd_reset(start),
        .rd_data(tx_data),
        .rd_en(tx_en),
        .empty()
    );

    // RX logic
    assign rx_en   = (state == STATE_CMD || state == STATE_RECEIVE) && cnt[1:0] == 2'b11;
    assign rx_data = {rx_shift, qspi_io};
    always_ff @(posedge qspi_clk or posedge start) begin
        if (start) begin
            cnt   <= '0;
            state <= STATE_CMD;
        end else begin
            cnt <= cnt + 1;

            rx_shift <= {rx_shift[7:0], qspi_io};

            if (state == STATE_CMD && cnt == 3'd1) begin
                has_resp <= (qspi_io[0] == 1'b0);  // Detect if the command expects a response
                state <= STATE_RECEIVE;
            end else if (state == STATE_RECEIVE && has_resp && cnt == 3'd7) state <= STATE_DUMMY;
            else if (state == STATE_DUMMY && cnt == 3'd3) state <= STATE_SEND;
        end
    end

    // TX logic
    assign tx_en   = (state == STATE_SEND && cnt[1:0] == 2'b11);
    assign qspi_io = (state == STATE_SEND) ? io_out : 'z;
    always_ff @(negedge qspi_clk) begin
        if (cnt[1:0] == 2'b00) begin
            io_out   <= tx_data[15:12];
            // Load new word from FIFO
            tx_shift <= tx_data[11:0];
        end else begin
            io_out   <= tx_shift[11:8];
            // Shift out
            tx_shift <= {tx_shift[7:0], 4'b0};
        end
    end

    // Start detection
    assign start = (start_sync[2:1] == 2'b10);
    always_ff @(posedge clk) begin
        start_sync <= {start_sync[1:0], qspi_ncs};
    end
endmodule
