module sdram #(
    parameter ROW_BITS = 12,
    parameter COL_BITS = 8
) (
    // SDRAM interface
    input logic init,  // Allow SDRAM to initialize
    sdram_bus.slave ch0,  // SDRAM bus with priority 0
    sdram_bus.slave ch1,  // SDRAM bus with priority 1
    sdram_bus.slave ch2,  // SDRAM bus with priority 2
    input logic refresh,  // External refresh signal

    // SDRAM signals
    input logic sdram_clk,
    output logic sdram_cs,
    output logic [ROW_BITS-1:0] sdram_addr,
    output logic [1:0] sdram_ba,
    inout wire [15:0] sdram_dq,
    output logic sdram_ras,
    output logic sdram_cas,
    output logic sdram_we,
    output logic sdram_dqm
);
    typedef shortint unsigned uint16;

    localparam uint16 INITIAL_PAUSE = 20_000;  // 200E-6 * FREQ
    localparam PRECHARGE_PERIOD = 2;  // tRP 15E-9 * FREQ
    localparam REGISTER_SET = 2;  // tRSC clocks
    localparam ACTIVE_TO_CMD = 2;  // tRCD 15E-9 * FREQ
    localparam CAS_LATENCY = 2;  // 2 or 3 clocks allowed. 3 for >133MHz
    localparam READ_PERIOD = 7;  // tRAS + tRP
    localparam WRITE_PERIOD = 9;  // tRAS + tRP + tWR
    localparam REFRESH_INTERVAL = 1560;  // tREF / 4K(8K) 15.6E-6 * FREQ

    // configure steps
    localparam CONFIGURE_PRECHARGE = 0;
    localparam CONFIGURE_SET_MODE = CONFIGURE_PRECHARGE + PRECHARGE_PERIOD;
    localparam CONFIGURE_REFRESH_1 = CONFIGURE_SET_MODE + REGISTER_SET;
    // READ_PERIOD cover the refresh period
    localparam CONFIGURE_REFRESH_2 = CONFIGURE_REFRESH_1 + READ_PERIOD + 1;
    localparam CONFIGURE_END = CONFIGURE_REFRESH_2 + READ_PERIOD;

    // active steps
    localparam ACTIVE_START = 1;
    localparam ACTIVE_CMD = ACTIVE_TO_CMD;
    localparam ACTIVE_READY = ACTIVE_TO_CMD + CAS_LATENCY + 1;
    localparam ACTIVE_READ_END = READ_PERIOD;
    localparam ACTIVE_WRITE_END = WRITE_PERIOD;

    localparam CMD_NOOP = 3'b111;
    localparam CMD_ACTIVATE = 3'b011;
    localparam CMD_MODE_REGISTER_SET = 3'b000;
    localparam CMD_AUTO_REFRESH = 3'b001;
    localparam CMD_READ = 3'b101;
    localparam CMD_WRITE = 3'b100;
    localparam CMD_PRECHARGE = 3'b010;

    enum bit [2:0] {
        STATE_POWERUP,
        STATE_CONFIGURE,
        STATE_IDLE,
        STATE_ACTIVE,
        STATE_REFRESH
    } state = STATE_POWERUP;

    logic [2:0] cmd;
    uint16 timer = 0;
    logic pending_refresh;
    bit [3:0] step;
    logic [1:0] bank;
    logic [COL_BITS-1:0] column;
    logic [15:0] data;
    bit [1:0] curr_ch;
    logic we;

    assign {sdram_ras, sdram_cas, sdram_we} = cmd;
    assign sdram_cs = (cmd == CMD_NOOP);
    assign sdram_dq = (cmd == CMD_WRITE) ? data : 'z;

    always_ff @(posedge sdram_clk) begin
        timer <= timer + 1'd1;

        if (timer >= REFRESH_INTERVAL || ((timer >= REFRESH_INTERVAL / 2) && refresh)) begin
            pending_refresh <= 1;
        end

        case (state)
            STATE_POWERUP: begin
                case (timer)
                    0: begin
                        sdram_ba <= 'x;
                        sdram_addr <= 'x;
                        sdram_dqm <= 1'b1;
                        cmd <= CMD_NOOP;
                    end
                    INITIAL_PAUSE: begin
                        if (init) begin
                            timer <= 0;
                            state <= STATE_CONFIGURE;
                        end
                    end
                endcase
            end
            STATE_CONFIGURE: begin
                case (timer)
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
                        sdram_ba <= 'x;
                        sdram_addr <= 'x;
                        cmd <= CMD_AUTO_REFRESH;
                    end
                    CONFIGURE_END: begin
                        timer <= 0;
                        pending_refresh <= 0;
                        state <= STATE_IDLE;
                    end
                    default: cmd <= CMD_NOOP;
                endcase
            end
            STATE_IDLE: begin
                sdram_ba <= 'x;
                sdram_addr <= 'x;
                sdram_dqm <= 'x;
                cmd <= CMD_NOOP;
                step <= 4'(ACTIVE_START);

                if (pending_refresh) begin
                    pending_refresh <= 0;
                    timer <= 0;
                    cmd <= CMD_AUTO_REFRESH;
                    state <= STATE_REFRESH;
                end else if (ch0.req != ch0.ack) begin
                    {sdram_ba, column, sdram_addr} <= ch0.address;
                    data <= ch0.we ? ch0.data_write : 'x;
                    bank <= {ch0.address[ch0.ADDR_BITS-1-:2]};
                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    curr_ch <= 0;
                    we <= ch0.we;
                end else if (ch1.req != ch1.ack) begin
                    {sdram_ba, column, sdram_addr} <= ch1.address;
                    data <= ch1.we ? ch1.data_write : 'x;
                    bank <= {ch1.address[ch1.ADDR_BITS-1-:2]};
                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    curr_ch <= 1;
                    we <= ch1.we;
                end else if (ch2.req != ch2.ack) begin
                    {sdram_ba, column, sdram_addr} <= ch2.address;
                    data <= ch2.we ? ch2.data_write : 'x;
                    bank <= {ch2.address[ch2.ADDR_BITS-1-:2]};
                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    curr_ch <= 2;
                    we <= ch2.we;
                end
            end
            STATE_ACTIVE: begin
                step <= step + 1'd1;

                case (step)
                    ACTIVE_CMD: begin
                        sdram_ba <= bank;
                        sdram_addr <= {{ROW_BITS - COL_BITS{1'b0}}, column};
                        sdram_addr[10] <= 1;  // Auto-precharge
                        sdram_dqm <= 1'b0;
                        cmd <= we ? CMD_WRITE : CMD_READ;
                    end
                    ACTIVE_READY: begin
                        if (curr_ch == 0) begin
                            ch0.ack <= ch0.req;
                            if (!we) ch0.data_read <= sdram_dq;
                        end else if (curr_ch == 1) begin
                            ch1.ack <= ch1.req;
                            if (!we) ch1.data_read <= sdram_dq;
                        end else if (curr_ch == 2) begin
                            ch2.ack <= ch2.req;
                            if (!we) ch2.data_read <= sdram_dq;
                        end
                    end
                    ACTIVE_READ_END:  if (!we) state <= STATE_IDLE;
                    ACTIVE_WRITE_END: if (we) state <= STATE_IDLE;
                    default: begin
                        sdram_ba <= 'x;
                        sdram_addr <= 'x;
                        sdram_dqm <= 'x;
                        cmd <= CMD_NOOP;
                    end
                endcase

            end
            STATE_REFRESH: begin
                cmd <= CMD_NOOP;
                if (timer == READ_PERIOD) begin
                    timer <= 0;
                    state <= STATE_IDLE;
                end
            end
            default;
        endcase
    end

endmodule
