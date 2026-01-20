module sdram #(
    parameter ROW_BITS = 12,
    parameter COL_BITS = 8
) (
    // SDRAM interface
    input logic clk,
    input logic reset,  // Reset signal
    sdram_bus.memory ch0,  // SDRAM bus with priority 0
    sdram_bus.memory ch1,  // SDRAM bus with priority 1
    sdram_bus.memory ch2,  // SDRAM bus with priority 2
    input logic refresh,  // External refresh signal

    // SDRAM signals
    output logic sdram_cs,
    output logic [ROW_BITS-1:0] sdram_addr,
    output logic [1:0] sdram_ba,
    inout wire [15:0] sdram_dq,
    output logic sdram_ras,
    output logic sdram_cas,
    output logic sdram_we,
    output logic [1:0] sdram_dqm
);
    localparam PRECHARGE_PERIOD = 5'd2;  // tRP 15E-9 * FREQ
    localparam REGISTER_SET = 5'd2;  // tRSC clocks
    localparam ACTIVE_TO_CMD = 5'd2;  // tRCD 15E-9 * FREQ
    localparam CAS_LATENCY = 5'd2;  // 2 or 3 clocks allowed. 3 for >100MHz
    localparam READ_PERIOD = 5'd6;  // tRAS + tRP
    localparam WRITE_PERIOD = 5'd8;  // tRAS + tRP + tWR
    localparam REFRESH_INTERVAL = 11'd1560;  // tREF / 4K 15.625E-6 * FREQ

    // configure steps
    localparam CONFIGURE_PRECHARGE = PRECHARGE_PERIOD;
    localparam CONFIGURE_SET_MODE = CONFIGURE_PRECHARGE + PRECHARGE_PERIOD;
    localparam CONFIGURE_REFRESH_1 = CONFIGURE_SET_MODE + REGISTER_SET;
    // READ_PERIOD cover the refresh period
    localparam CONFIGURE_REFRESH_2 = CONFIGURE_REFRESH_1 + READ_PERIOD + 5'd1;
    localparam CONFIGURE_END = CONFIGURE_REFRESH_2 + READ_PERIOD;

    // active steps
    localparam ACTIVE_START = 5'd1;
    localparam ACTIVE_CMD = ACTIVE_TO_CMD;
    localparam ACTIVE_READY = ACTIVE_TO_CMD + CAS_LATENCY + 5'd1;
    localparam ACTIVE_READ_END = READ_PERIOD;
    localparam ACTIVE_WRITE_END = WRITE_PERIOD;

    localparam CMD_NOOP = 3'b111;
    localparam CMD_ACTIVATE = 3'b011;
    localparam CMD_MODE_REGISTER_SET = 3'b000;
    localparam CMD_AUTO_REFRESH = 3'b001;
    localparam CMD_READ = 3'b101;
    localparam CMD_WRITE = 3'b100;
    localparam CMD_PRECHARGE = 3'b010;

    enum logic [1:0] {
        STATE_CONFIGURE,
        STATE_IDLE,
        STATE_ACTIVE,
        STATE_REFRESH
    } state;

    logic [2:0] cmd;
    logic [10:0] refresh_timer;
    logic pending_refresh;
    logic [4:0] step;
    logic [COL_BITS-1:0] column;
    logic [15:0] data;
    logic [1:0] curr_ch;
    logic we;
    logic [1:0] wm;
    logic [2:0] pending_req;

    assign {sdram_ras, sdram_cas, sdram_we} = cmd;
    assign sdram_cs = (cmd == CMD_NOOP);
    assign sdram_dq = (cmd == CMD_WRITE) ? data : 'z;

    always_ff @(posedge clk) begin
        refresh_timer <= refresh_timer + 1;

        if (refresh_timer >= REFRESH_INTERVAL || ((refresh_timer >= REFRESH_INTERVAL / 2) && refresh)) begin
            pending_refresh <= 1;
        end

        pending_req <= pending_req | {ch2.req, ch1.req, ch0.req};
        {ch2.ack, ch1.ack, ch0.ack} <= '0;

        if (reset) begin
            state <= STATE_CONFIGURE;
            cmd <= CMD_NOOP;
            step <= '0;
            pending_req <= 3'b000;
        end else begin
            case (state)
                STATE_CONFIGURE: begin
                    step <= step + 5'd1;

                    case (step)
                        CONFIGURE_PRECHARGE: begin
                            sdram_addr[10] <= 1'b1;  // precharge all banks
                            cmd <= CMD_PRECHARGE;
                        end
                        CONFIGURE_SET_MODE: begin
                            sdram_addr <= {
                                {ROW_BITS - 10{1'b0}},
                                1'd1,  // write mode - burst read and single write
                                2'b00,
                                3'(CAS_LATENCY),
                                1'd0,  // sequential addressing mode
                                3'd0  // burst length
                            };
                            sdram_ba <= '0;
                            cmd <= CMD_MODE_REGISTER_SET;
                        end
                        CONFIGURE_REFRESH_1, CONFIGURE_REFRESH_2: begin
                            cmd <= CMD_AUTO_REFRESH;
                        end
                        CONFIGURE_END: begin
                            refresh_timer <= '0;
                            pending_refresh <= 0;
                            state <= STATE_IDLE;
                        end
                        default: cmd <= CMD_NOOP;
                    endcase
                end
                STATE_IDLE: begin
                    cmd <= CMD_NOOP;
                    step <= ACTIVE_START;
                    sdram_dqm <= 2'b11;

                    // prioritize refresh over requests
                    if (pending_refresh) begin
                        pending_refresh <= 0;
                        refresh_timer <= '0;
                        cmd <= CMD_AUTO_REFRESH;
                        state <= STATE_REFRESH;
                    end else if (ch0.req || pending_req[0]) begin
                        {sdram_ba, column, sdram_addr} <= ch0.address;
                        data <= ch0.data_write;
                        cmd <= CMD_ACTIVATE;
                        state <= STATE_ACTIVE;
                        curr_ch <= 2'd0;
                        we <= ch0.we;
                        wm <= ch0.wm;
                        pending_req[0] <= 1'b0;
                    end else if (ch1.req || pending_req[1]) begin
                        {sdram_ba, column, sdram_addr} <= ch1.address;
                        data <= ch1.data_write;
                        cmd <= CMD_ACTIVATE;
                        state <= STATE_ACTIVE;
                        curr_ch <= 2'd1;
                        we <= ch1.we;
                        wm <= ch1.wm;
                        pending_req[1] <= 1'b0;
                    end else if (ch2.req || pending_req[2]) begin
                        {sdram_ba, column, sdram_addr} <= ch2.address;
                        data <= ch2.data_write;
                        cmd <= CMD_ACTIVATE;
                        state <= STATE_ACTIVE;
                        curr_ch <= 2'd2;
                        we <= ch2.we;
                        wm <= ch2.wm;
                        pending_req[2] <= 1'b0;
                    end
                end
                STATE_ACTIVE: begin
                    step <= step + 1;

                    case (step)
                        ACTIVE_CMD: begin
                            sdram_addr <= {{ROW_BITS - COL_BITS{1'b0}}, column};
                            sdram_addr[10] <= 1'b1;  // Auto-precharge
                            sdram_dqm <= we ? wm : 2'b00;
                            cmd <= we ? CMD_WRITE : CMD_READ;
                        end
                        ACTIVE_READY: begin
                            case (curr_ch)
                                2'd0: begin
                                    if (!we) ch0.data_read <= sdram_dq;
                                    ch0.ack <= 1;
                                end
                                2'd1: begin
                                    if (!we) ch1.data_read <= sdram_dq;
                                    ch1.ack <= 1;
                                end
                                2'd2: begin
                                    if (!we) ch2.data_read <= sdram_dq;
                                    ch2.ack <= 1;
                                end
                                default;
                            endcase
                        end
                        ACTIVE_READ_END: if (!we) state <= STATE_IDLE;
                        ACTIVE_WRITE_END: if (we) state <= STATE_IDLE;
                        default: cmd <= CMD_NOOP;
                    endcase
                end
                STATE_REFRESH: begin
                    cmd  <= CMD_NOOP;
                    step <= step + 1;
                    if (step == READ_PERIOD) state <= STATE_IDLE;
                end
            endcase
        end
    end

`ifdef DEBUG
    logic debug_busy = (state == STATE_ACTIVE);
    logic debug_refresh = (state == STATE_REFRESH);
`endif
endmodule
