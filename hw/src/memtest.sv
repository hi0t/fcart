module memtest (
    input logic clk,
    sdram_bus.master sdram
);
    localparam TEST_SEQ = 16'h1234;

    enum bit [1:0] {
        STATE_IDLE,
        STATE_WRITE,
        STATE_READ,
        STATE_END
    } state = STATE_IDLE;

    shortint unsigned timer = 0;
    logic [15:0] expected;
    (* noprune *) bit fail = 0;

    always_ff @(posedge clk) begin
        case (state)
            STATE_IDLE: begin
                timer <= timer + 1'd1;
                if (timer == 40_000) begin
                    state <= STATE_WRITE;
                    sdram.we <= 1;
                    sdram.address <= 1;
                    sdram.data_write <= TEST_SEQ;
                    sdram.req <= !sdram.req;
                end
            end
            STATE_WRITE: begin
                if (sdram.req == sdram.ack) begin
                    if (sdram.address == 0) begin
                        state <= STATE_READ;
                        sdram.we <= 0;
                        sdram.address <= 1;
                        expected <= TEST_SEQ;
                        sdram.req <= !sdram.req;
                    end else begin
                        sdram.address <= sdram.address << 1;
                        sdram.data_write <= {sdram.data_write[14:0], sdram.data_write[15]};
                        sdram.req <= !sdram.req;
                    end
                end
            end
            STATE_READ: begin
                if (sdram.address == 0) begin
                    state <= STATE_END;
                end else if (sdram.req == sdram.ack) begin
                    if (sdram.data_read != expected) begin
                        fail  <= 1;
                        state <= STATE_END;
                    end else begin
                        sdram.address <= sdram.address << 1;
                        expected <= {expected[14:0], expected[15]};
                        sdram.req <= !sdram.req;
                    end
                end
            end
            STATE_END: begin
                state <= STATE_IDLE;
                timer <= 0;
            end

        endcase
    end
endmodule
