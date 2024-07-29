module sdio (
    inout wire cmd_sdio,

    sdio_bus.host bus
);
    enum logic [1:0] {
        STATE_REQ_IDLE = 2'd0,
        STATE_REQ_PAYLOAD = 2'd1,
        STATE_RESP_IDLE = 2'd2,
        STATE_RESP_PAYLOAD = 2'd3
    } state = STATE_REQ_IDLE;

    logic crc_enable;
    logic [6:0] crc_buf;
    logic [6:0] actual_crc;
    bit [5:0] bit_cnt;
    logic [1:0] tx_delay;  // Queue to look ahead when calculating CRC response
    logic cmd_prev;

    assign cmd_sdio = (state == STATE_REQ_IDLE || state == STATE_REQ_PAYLOAD) ? 'z : tx_delay[1];

    crc7 crc7 (
        .clk(bus.clk),
        .clear(state == STATE_REQ_IDLE || state == STATE_RESP_IDLE),
        .enable(crc_enable),
        .in((state == STATE_REQ_IDLE || state == STATE_REQ_PAYLOAD) ? cmd_sdio : tx_delay[0]),
        .crc(actual_crc)
    );

    always_ff @(posedge bus.clk) begin
        bus.req_valid <= 0;

        case (state)
            STATE_REQ_IDLE: begin
                cmd_prev <= cmd_sdio;
                if (cmd_prev && !cmd_sdio) begin  // Falling edge detect
                    crc_enable <= 1;
                    bit_cnt <= 0;
                    bus.req_cmd <= 0;
                    bus.req_arg <= 0;
                    crc_buf <= 0;
                    state <= STATE_REQ_PAYLOAD;
                end
            end

            STATE_REQ_PAYLOAD: begin
                bit_cnt <= bit_cnt + 6'd1;

                if (bit_cnt >= 1 && bit_cnt < 7) bus.req_cmd <= {bus.req_cmd[4:0], cmd_sdio};
                else if (bit_cnt >= 7 && bit_cnt < 39) bus.req_arg <= {bus.req_arg[30:0], cmd_sdio};
                else if (bit_cnt >= 39 && bit_cnt < 46) crc_buf <= {crc_buf[5:0], cmd_sdio};

                case (bit_cnt)
                    0:  if (cmd_sdio != 1'b1) state <= STATE_REQ_IDLE;  // Transmission bit
                    38: crc_enable <= 0;
                    46:  // End bit
                    if (cmd_sdio && actual_crc == crc_buf) begin
                        tx_delay <= 'b11;  // Turn high when idle
                        bus.req_valid <= 1;
                        state <= STATE_RESP_IDLE;
                    end else state <= STATE_REQ_IDLE;
                endcase
            end

            STATE_RESP_IDLE: begin
                if (bus.resp_valid == 1) begin
                    bit_cnt <= 0;
                    tx_delay <= 'b00;  // Start bit and transmission bit
                    crc_enable <= 1;
                    state <= STATE_RESP_PAYLOAD;
                end else if (bus.resp_valid == 2) state <= STATE_REQ_IDLE;
            end

            STATE_RESP_PAYLOAD: begin
                bit_cnt <= bit_cnt + 6'd1;

                if (bit_cnt < 6) tx_delay <= {tx_delay[0], bus.req_cmd[5-bit_cnt]};
                else if (bit_cnt >= 6 && bit_cnt < 38)
                    tx_delay <= {tx_delay[0], bus.resp_arg[37-bit_cnt]};
                // Looking ahead to calculate the crc. The writing is performed with an offset of 1
                else if (bit_cnt == 38) tx_delay[1] <= tx_delay[0];
                else if (bit_cnt >= 39 && bit_cnt < 46) tx_delay[1] <= actual_crc[45-bit_cnt];

                case (bit_cnt)
                    38: crc_enable <= 0;
                    46: tx_delay[1] <= 1'b1;  // End bit
                    47: state <= STATE_REQ_IDLE;
                endcase
            end
        endcase
    end
endmodule
