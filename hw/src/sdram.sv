module sdram #(
    parameter ADDR_BITS = 12,
    parameter COLUMN_BITS = 8,
    parameter REFRESH_INTERVAL = 2080  // tREF / 4K(8K) 15.6E-6 * FREQ
) (
    input logic clk,
    input logic init,
    sdram_bus.host ch0,
    sdram_bus.host ch1,
    sdram_bus.host ch2,

    // SDRAM chip interface
    output logic SDRAM_CKE,
    output logic SDRAM_CS,
    output logic [ADDR_BITS-1:0] SDRAM_ADDR,
    output logic [1:0] SDRAM_BA,
    inout wire [15:0] SDRAM_DQ,
    output logic SDRAM_RAS,
    output logic SDRAM_CAS,
    output logic SDRAM_WE,
    output logic [1:0] SDRAM_DQM
);
    typedef shortint unsigned uint16;

    localparam uint16 INITIAL_PAUSE = 26_667;  // 200E-6 * FREQ
    localparam PRECHARGE_PERIOD = 2;  // tRP 15E-9 * FREQ
    localparam REGISTER_SET = 2;  // tRSC clocks
    localparam ACTIVE_TO_CMD = 2;  // tRCD 15E-9 * FREQ
    localparam CAS_LATENCY = 2;  // 2 or 3 clocks allowed. 3 for >133MHz
    localparam READ_PERIOD = 7;  // tRAS + tRP
    localparam WRITE_PERIOD = 9;  // tRAS + tRP + tWR

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

    localparam USER_ADDR_BITS = 2 + COLUMN_BITS + ADDR_BITS;

    enum bit [2:0] {
        STATE_POWERUP = 3'd0,
        STATE_CONFIGURE = 3'd1,
        STATE_IDLE = 3'd2,
        STATE_ACTIVE = 3'd3,
        STATE_REFRESH = 3'd4
    } state = STATE_POWERUP;

    logic [2:0] cmd;
    logic [1:0] curr_ch;
    logic [1:0] bank_save;
    logic [COLUMN_BITS-1:0] col_save;
    logic [15:0] data_save;
    logic we;
    logic refresh;
    bit [3:0] step = 0;
    uint16 timer = 0;

    assign {SDRAM_RAS, SDRAM_CAS, SDRAM_WE} = cmd;
    assign SDRAM_CS = (cmd == CMD_NOOP);
    assign SDRAM_DQ = (cmd == CMD_WRITE) ? data_save : 'z;
    assign SDRAM_CKE = 1;
    assign refresh = (ch0.refresh | ch1.refresh | ch2.refresh);
    assign ch0.data_read = SDRAM_DQ;
    assign ch1.data_read = SDRAM_DQ;
    assign ch2.data_read = SDRAM_DQ;

    always_ff @(posedge clk) begin
        timer <= timer + 1'd1;

        case (state)
            STATE_POWERUP: begin
                case (timer)
                    0: begin
                        SDRAM_BA <= 'x;
                        SDRAM_ADDR <= 'x;
                        SDRAM_DQM <= 2'b11;
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
                        SDRAM_ADDR[10] <= 1'b1;  // precharge all banks
                        cmd <= CMD_PRECHARGE;
                    end
                    CONFIGURE_SET_MODE: begin
                        SDRAM_ADDR <= {
                            {ADDR_BITS - 10{1'b0}},
                            1'd1,  // write mode - burst read and single write
                            2'b00,
                            3'(CAS_LATENCY),
                            1'd0,  // sequential addressing mode
                            3'd0  // burst length
                        };
                        SDRAM_BA <= '0;
                        cmd <= CMD_MODE_REGISTER_SET;
                    end
                    CONFIGURE_REFRESH_1, CONFIGURE_REFRESH_2: begin
                        SDRAM_BA <= 'x;
                        SDRAM_ADDR <= 'x;
                        cmd <= CMD_AUTO_REFRESH;
                    end
                    CONFIGURE_END: begin
                        timer <= 0;
                        state <= STATE_IDLE;
                    end
                    default: cmd <= CMD_NOOP;
                endcase
            end
            STATE_IDLE: begin
                SDRAM_BA <= 'x;
                SDRAM_ADDR <= 'x;
                SDRAM_DQM <= 'x;
                cmd <= CMD_NOOP;
                step <= 4'(ACTIVE_START);

                if (timer >= REFRESH_INTERVAL || ((timer >= REFRESH_INTERVAL / 2) && refresh)) begin
                    timer <= 0;
                    cmd   <= CMD_AUTO_REFRESH;
                    state <= STATE_REFRESH;
                end else if (ch0.req != ch0.ack) begin
                    bank_save <= ch0.address[USER_ADDR_BITS-1-:2];
                    col_save <= ch0.address[ADDR_BITS+:COLUMN_BITS];
                    data_save <= ch0.we ? ch0.data_write : 'x;

                    SDRAM_BA <= ch0.address[USER_ADDR_BITS-1-:2];
                    SDRAM_ADDR <= ch0.address[ADDR_BITS-1:0];
                    cmd <= CMD_ACTIVATE;

                    state <= STATE_ACTIVE;
                    curr_ch <= 0;
                    we <= ch0.we;
                end else if (ch1.req != ch1.ack) begin
                    bank_save <= ch1.address[USER_ADDR_BITS-1-:2];
                    col_save <= ch1.address[ADDR_BITS+:COLUMN_BITS];
                    data_save <= ch1.we ? ch1.data_write : 'x;

                    SDRAM_BA <= ch1.address[USER_ADDR_BITS-1-:2];
                    SDRAM_ADDR <= ch1.address[ADDR_BITS-1:0];
                    cmd <= CMD_ACTIVATE;

                    state <= STATE_ACTIVE;
                    curr_ch <= 1;
                    we <= ch1.we;
                end else if (ch2.req != ch2.ack) begin
                    bank_save <= ch2.address[USER_ADDR_BITS-1-:2];
                    col_save <= ch2.address[ADDR_BITS+:COLUMN_BITS];
                    data_save <= ch2.we ? ch2.data_write : 'x;

                    SDRAM_BA <= ch2.address[USER_ADDR_BITS-1-:2];
                    SDRAM_ADDR <= ch2.address[ADDR_BITS-1:0];
                    cmd <= CMD_ACTIVATE;

                    state <= STATE_ACTIVE;
                    curr_ch <= 2;
                    we <= ch2.we;
                end
            end
            STATE_ACTIVE: begin
                step <= step + 1'd1;
                /* verilog_format: off */
                casez ({step, we})
                    {4'(ACTIVE_CMD), 1'b?} : begin
                        SDRAM_BA <= bank_save;
                        SDRAM_ADDR <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, col_save};
                        SDRAM_ADDR[10] <= 1;  // Auto-precharge
                        SDRAM_DQM <= 2'b00;
                        cmd <= we ? CMD_WRITE : CMD_READ;
                    end
                    {4'(ACTIVE_READY), 1'b?}: begin
                        if (curr_ch == 0) ch0.ack <= ch0.req;
                        else if (curr_ch == 1) ch1.ack <= ch1.req;
                        else if (curr_ch == 2) ch2.ack <= ch2.req;
                    end
                    {4'(ACTIVE_READ_END), 1'b0}, {4'(ACTIVE_WRITE_END), 1'b1}: state <= STATE_IDLE;
                    default: begin
                        SDRAM_BA <= 'x;
                        SDRAM_ADDR <= 'x;
                        SDRAM_DQM <= 'x;
                        cmd <= CMD_NOOP;
                    end
                endcase
                /* verilog_format: on */
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
