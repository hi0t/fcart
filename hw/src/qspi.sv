module qspi (
    input logic clk,
    input logic async_reset,

    input logic qspi_clk,
    input logic qspi_ncs,
    inout wire [3:0] qspi_io,

    output logic [7:0] rd_data,
    output logic rd_valid,
    input logic [7:0] wr_data,
    output logic wr_valid,
    output logic start
);
    enum logic [1:0] {
        STATE_CMD,
        STATE_RECEIVE,
        STATE_DUMMY,
        STATE_SEND
    } state;

    logic qspi_reset;
    logic [2:0] cnt;
    logic [3:0] upper_nibble;
    logic [2:0] start_sync, rd_sync, wr_sync;
    logic rx_done;
    logic has_resp;

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
            else if (state != STATE_DUMMY && state != STATE_SEND) begin
                rd_data <= {upper_nibble, qspi_io};
                rx_done <= 1'b1;
            end

            if (state == STATE_CMD && cnt == 3'd1) begin
                has_resp <= (qspi_io[0] == 1'b0);  // Detect if the command expects a response
                state <= STATE_RECEIVE;
            end

            if (state == STATE_RECEIVE && cnt == 3'd7 && has_resp) begin  // Capture 24-bit address
                state <= STATE_DUMMY;
            end

            if (state == STATE_DUMMY && cnt == 3'd3) begin
                state <= STATE_SEND;
            end
        end
    end

    // TX logic
    logic [3:0] io_out, next_io_out;
    logic tx_sw;
    logic qspi_oe;

    assign qspi_io = qspi_oe ? io_out : 4'bz;

    always_ff @(negedge qspi_clk or posedge qspi_reset) begin
        if (qspi_reset) begin
            qspi_oe <= 1'b0;
        end else begin
            tx_sw <= 1'b0;

            if (state == STATE_SEND) begin
                qspi_oe <= 1'b1;
                if (!tx_sw) begin
                    io_out <= wr_data[7:4];
                    next_io_out <= wr_data[3:0];
                    tx_sw <= 1'b1;
                end else begin
                    io_out <= next_io_out;
                end
            end
        end
    end

    // QSPI clock domain to system clock domain synchronization
    assign start = (start_sync[2:1] == 2'b10);
    assign rd_valid = (rd_sync[2:1] == 2'b01);
    assign wr_valid = (wr_sync[2:1] == 2'b01);
    always_ff @(posedge clk) begin
        start_sync <= {start_sync[1:0], qspi_ncs};
        rd_sync    <= {rd_sync[1:0], rx_done};
        wr_sync    <= {wr_sync[1:0], (state == STATE_DUMMY && cnt == 3'd3) || (state == STATE_SEND && cnt[0] == 1'b1)};
    end

`ifdef DEBUG
    logic [3:0] debug_cnt;
    always_ff @(negedge qspi_clk or posedge qspi_reset) begin
        if (qspi_reset) begin
            debug_cnt <= 4'd0;
        end else begin
            debug_cnt <= debug_cnt + 4'd1;
        end
    end
`endif
endmodule
