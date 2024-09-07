module sdram #(
    parameter ADDR_BITS = 12,
    parameter COLUMN_BITS = 8,
    parameter REFRESH_INTERVAL = 2080  // tREF / 4K(8K) 15.6E-6 * FREQ
) (
    input logic clk,
    input logic init,
    sdram_bus.host ch0,
    sdram_bus.host ch1,
    input logic refresh,

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
    localparam ACTIVE_IDLE = 0;
    localparam ACTIVE_START = 1;
    localparam ACTIVE_CMD = ACTIVE_TO_CMD;
    localparam ACTIVE_READY = ACTIVE_TO_CMD + CAS_LATENCY + 1;
    localparam ACTIVE_LOW_Z = ACTIVE_READY + 1;  // Write permission while reading in parallel
    localparam ACTIVE_READ_END = READ_PERIOD;
    localparam ACTIVE_WRITE_END = WRITE_PERIOD;

    localparam CMD_NOOP = 3'b111;
    localparam CMD_ACTIVATE = 3'b011;
    localparam CMD_MODE_REGISTER_SET = 3'b000;
    localparam CMD_AUTO_REFRESH = 3'b001;
    localparam CMD_READ = 3'b101;
    localparam CMD_WRITE = 3'b100;
    localparam CMD_PRECHARGE = 3'b010;

    enum bit [1:0] {
        STATE_POWERUP = 2'd0,
        STATE_CONFIGURE = 2'd1,
        STATE_ACTIVE = 2'd2,
        STATE_REFRESH = 2'd3
    } state = STATE_POWERUP;

    typedef struct {
        bit [3:0] step;
        logic [1:0] bank;
        logic [COLUMN_BITS-1:0] col;
        logic [15:0] data;
        logic we;
    } bank_port;
    bank_port port0, port1;

    logic [2:0] cmd;
    logic [15:0] data_tx;
    logic pending_refresh;
    logic ba_allow;
    logic write_allow;
    uint16 timer = 0;

    assign {SDRAM_RAS, SDRAM_CAS, SDRAM_WE} = cmd;
    assign SDRAM_CS = (cmd == CMD_NOOP);
    assign SDRAM_DQ = (cmd == CMD_WRITE) ? data_tx : 'z;
    assign SDRAM_CKE = 1;

    always_ff @(posedge clk) begin
        timer <= timer + 1'd1;

        if (timer >= REFRESH_INTERVAL || ((timer >= REFRESH_INTERVAL / 2) && refresh)) begin
            pending_refresh <= 1;
        end

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
                        pending_refresh <= 0;
                        write_allow <= 1;
                        state <= STATE_ACTIVE;
                    end
                    default: cmd <= CMD_NOOP;
                endcase
            end
            STATE_ACTIVE: begin
                SDRAM_BA <= 'x;
                SDRAM_ADDR <= 'x;
                SDRAM_DQM <= 'x;
                cmd <= CMD_NOOP;
                ba_allow <= 1;

                // RAS stage
                if (port0.step == ACTIVE_IDLE && port1.step == ACTIVE_IDLE && pending_refresh) begin
                    pending_refresh <= 0;
                    timer <= 0;
                    cmd <= CMD_AUTO_REFRESH;
                    state <= STATE_REFRESH;
                end else if (port0.step == ACTIVE_IDLE && !pending_refresh && ba_allow && ch0.req != ch0.ack) begin
                    port0.step <= 4'(ACTIVE_START);
                    port0.bank <= {1'b0, ch0.address[ch0.ADDR_BITS-1-:1]};
                    port0.col <= ch0.address[ADDR_BITS+:COLUMN_BITS];
                    port0.data <= ch0.we ? ch0.data_write : 'x;
                    port0.we <= ch0.we;

                    SDRAM_BA <= {1'b0, ch0.address[ch0.ADDR_BITS-1-:1]};
                    SDRAM_ADDR <= ch0.address[ADDR_BITS-1:0];

                    cmd <= CMD_ACTIVATE;
                    ba_allow <= 0;  // Skip bank activation next cycle to satisfy tRRD.
                end else if (port1.step == ACTIVE_IDLE && !pending_refresh && ba_allow && ch1.req != ch1.ack) begin
                    port1.step <= 4'(ACTIVE_START);
                    port1.bank <= {1'b1, ch1.address[ch1.ADDR_BITS-1-:1]};
                    port1.col <= ch1.address[ADDR_BITS+:COLUMN_BITS];
                    port1.data <= ch1.we ? ch1.data_write : 'x;
                    port1.we <= ch1.we;

                    SDRAM_BA <= {1'b1, ch1.address[ch1.ADDR_BITS-1-:1]};
                    SDRAM_ADDR <= ch1.address[ADDR_BITS-1:0];

                    cmd <= CMD_ACTIVATE;
                    ba_allow <= 0;
                end else if (port0.step == ACTIVE_CMD && (!port0.we || write_allow)) begin  // CAS stage
                    SDRAM_BA <= port0.bank;
                    SDRAM_ADDR <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, port0.col};
                    SDRAM_ADDR[10] <= 1;  // Auto-precharge
                    SDRAM_DQM <= 2'b00;

                    if (port0.we) begin
                        cmd <= CMD_WRITE;
                        data_tx <= port0.data;
                    end else begin
                        cmd <= CMD_READ;
                        write_allow <= 0;
                    end

                    port0.step <= port0.step + 1'd1;
                end else if (port1.step == ACTIVE_CMD && (!port1.we || write_allow)) begin
                    SDRAM_BA <= port1.bank;
                    SDRAM_ADDR <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, port1.col};
                    SDRAM_ADDR[10] <= 1;  // Auto-precharge
                    SDRAM_DQM <= 2'b00;

                    if (port1.we) begin
                        cmd <= CMD_WRITE;
                        data_tx <= port1.data;
                    end else begin
                        cmd <= CMD_READ;
                        write_allow <= 0;
                    end

                    port1.step <= port1.step + 1'd1;
                end

                // The remaining stages are carried out in parallel
                if (port0.step != ACTIVE_IDLE && port0.step != ACTIVE_CMD)
                    port0.step <= port0.step + 1'd1;
                if (port1.step != ACTIVE_IDLE && port1.step != ACTIVE_CMD)
                    port1.step <= port1.step + 1'd1;

                /* verilog_format: off */
                case ({port0.step, port0.we})
                    {4'(ACTIVE_READY), 1'b0}: begin
                        ch0.data_read <= SDRAM_DQ;
                        ch0.ack <= ch0.req;
                    end
                    {4'(ACTIVE_LOW_Z), 1'b0}: write_allow <= 1;
                    {4'(ACTIVE_READ_END), 1'b0}: port0.step <= 4'(ACTIVE_IDLE);
                    {4'(ACTIVE_WRITE_END), 1'b1}: begin
                        port0.step <= 4'(ACTIVE_IDLE);
                        ch0.ack <= ch0.req;
                    end
                    default;
                endcase
                case ({port1.step, port1.we})
                    {4'(ACTIVE_READY), 1'b0}: begin
                        ch1.data_read <= SDRAM_DQ;
                        ch1.ack <= ch1.req;
                    end
                    {4'(ACTIVE_LOW_Z), 1'b0}: write_allow <= 1;
                    {4'(ACTIVE_READ_END), 1'b0}: port1.step <= 4'(ACTIVE_IDLE);
                    {4'(ACTIVE_WRITE_END), 1'b1}: begin
                        port1.step <= 4'(ACTIVE_IDLE);
                        ch1.ack <= ch1.req;
                    end
                    default;
                endcase
                /* verilog_format: on */
            end
            STATE_REFRESH: begin
                cmd <= CMD_NOOP;
                if (timer == READ_PERIOD) begin
                    timer <= 0;
                    state <= STATE_ACTIVE;
                end
            end
        endcase
    end
endmodule
