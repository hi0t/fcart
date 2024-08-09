module sdram #(
    parameter ADDR_BITS = 12,
    parameter COLUMN_BITS = 8,
    parameter REFRESH_INTERVAL = 2080  // tREF / 4K(8K) 15.6E-6 * FREQ
) (
    input logic clk,
    input logic init,
    sdram_bus.host ch0,
    sdram_bus.host ch1,
    sdram_bus.host ch2,  // 16 bit

    // SDRAM chip interface
    output logic cke,
    output logic cs,
    output logic [ADDR_BITS-1:0] address,
    output logic [1:0] bank,
    inout wire [15:0] dq,
    output logic ras,
    output logic cas,
    output logic we,
    output logic [1:0] dqm
);
    typedef byte unsigned uint8;
    typedef shortint unsigned uint16;

    localparam uint16 INITIAL_PAUSE = 26_667;  // 200E-6 * FREQ
    localparam uint8 PRECHARGE_PERIOD = 2;  // tRP 15E-9 * FREQ
    localparam uint8 REGISTER_SET = 2;  // tRSC clocks
    localparam uint8 ACTIVE_TO_CMD = 2;  // tRCD 15E-9 * FREQ
    localparam uint8 CAS_LATENCY = 2;  // 2 or 3 clocks allowed. 3 for >133MHz
    localparam uint8 READ_PERIOD = 8;  // tRAS + tRP
    localparam uint8 WRITE_PERIOD = 10;  // tRAS + tRP + tWR

    // configure steps
    localparam CONFIGURE_PRECHARGE = 0;
    localparam CONFIGURE_SET_MODE = CONFIGURE_PRECHARGE + PRECHARGE_PERIOD;
    localparam CONFIGURE_REFRESH_1 = CONFIGURE_SET_MODE + REGISTER_SET;
    // READ_PERIOD cover the refresh period
    localparam CONFIGURE_REFRESH_2 = CONFIGURE_REFRESH_1 + READ_PERIOD;
    localparam CONFIGURE_END = CONFIGURE_REFRESH_2 + READ_PERIOD;

    // active steps
    localparam ACTIVE_START = uint8'(1);  // 0 - iddle
    localparam ACTIVE_CMD = ACTIVE_TO_CMD;
    localparam ACTIVE_READY = ACTIVE_TO_CMD + CAS_LATENCY + uint8'(1);
    localparam ACTIVE_READ = READ_PERIOD;
    localparam ACTIVE_WRITE = WRITE_PERIOD - uint8'(1);

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
        STATE_IDLE = 2'd2,
        STATE_ACTIVE = 2'd3
    } state = STATE_POWERUP;

    enum bit [1:0] {
        OP_REFRESH = 2'd0,
        OP_READ = 2'd1,
        OP_WRITE = 2'd2
    } op;

    logic [2:0] cmd;
    logic [1:0] bank_save;
    logic [COLUMN_BITS-1:0] col_save;
    logic [15:0] data_save;
    logic low_bit;
    logic [15:0] data_tx;
    bit [2:0] write = 3'b0;
    bit read0, read1, read2;
    logic  refresh;
    uint16 timer = 0;
    uint8  step = 0;

    assign {ras, cas, we} = cmd;
    assign cs = (cmd == CMD_NOOP);
    assign dq = (cmd == CMD_WRITE) ? data_tx : 'z;
    assign cke = 1;
    assign refresh = (ch0.refresh_req | ch1.refresh_req | ch2.refresh_req);

    always_ff @(posedge clk) begin
        timer <= timer + 1'd1;

        read0 <= read0 | ch0.read_req;
        read1 <= read1 | ch1.read_req;
        read2 <= read2 | ch2.read_req;

        //read  <= read | {ch2.read_req, ch1.read_req, ch0.read_req};
        write <= write | {ch2.write_req, ch1.write_req, ch0.write_req};

        case (state)
            STATE_POWERUP: begin
                case (timer)
                    0: begin
                        bank <= 'x;
                        address <= 'x;
                        dqm <= 2'b11;
                        cmd <= CMD_NOOP;
                    end
                    INITIAL_PAUSE: begin
                        if (!init) timer <= INITIAL_PAUSE;
                        else begin
                            timer <= 0;
                            state <= STATE_CONFIGURE;
                        end
                    end
                endcase
            end
            STATE_CONFIGURE: begin
                step <= step + 1'd1;

                case (step)
                    CONFIGURE_PRECHARGE: begin
                        address[10] <= 1'b1;  // precharge all banks
                        cmd <= CMD_PRECHARGE;
                    end
                    CONFIGURE_SET_MODE: begin
                        address <= {
                            {ADDR_BITS - 10{1'b0}},
                            1'd1,  // write mode - burst read and single write
                            2'b00,
                            3'(CAS_LATENCY),
                            1'd0,  // sequential addressing mode
                            3'd0  // burst length
                        };
                        bank <= '0;
                        cmd <= CMD_MODE_REGISTER_SET;
                    end
                    CONFIGURE_REFRESH_1, CONFIGURE_REFRESH_2: begin
                        bank <= 'x;
                        address <= 'x;
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
                bank <= 'x;
                address <= 'x;
                dqm <= 'x;
                cmd <= CMD_NOOP;
                step <= ACTIVE_START;

                if (timer >= REFRESH_INTERVAL || ((timer >= REFRESH_INTERVAL / 2) && refresh)) begin
                    timer <= 0;
                    cmd <= CMD_AUTO_REFRESH;
                    op <= OP_REFRESH;
                    state <= STATE_ACTIVE;
                end else if (read0 || write[0]) begin
                    read0 <= 0;
                    write[0] <= 0;
                    ch0.busy <= 1;

                    bank <= ch0.address[ch0.USER_ADDR_BITS-1-:2];
                    address <= ch0.address[1+:ADDR_BITS];

                    bank_save <= ch0.address[ch0.USER_ADDR_BITS-1-:2];
                    col_save <= ch0.address[1+ADDR_BITS+:COLUMN_BITS];
                    data_save <= write[0] ? {ch0.data_write, ch0.data_write} : 'x;
                    low_bit <= ch0.address[0];

                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    op <= write[0] ? OP_WRITE : OP_READ;
                end else if (read1 || write[1]) begin
                    read1 <= 0;
                    write[1] <= 0;
                    ch1.busy <= 1;

                    bank <= ch1.address[ch1.USER_ADDR_BITS-1-:2];
                    address <= ch1.address[1+:ADDR_BITS];

                    bank_save <= ch1.address[ch1.USER_ADDR_BITS-1-:2];
                    col_save <= ch1.address[1+ADDR_BITS+:COLUMN_BITS];
                    data_save <= write[1] ? {ch1.data_write, ch1.data_write} : 'x;
                    low_bit <= ch1.address[0];

                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    op <= write[1] ? OP_WRITE : OP_READ;
                end else if (read2 || write[2]) begin
                    read2 <= 0;
                    write[2] <= 0;
                    ch2.busy <= 1;

                    bank <= ch2.address[ch2.USER_ADDR_BITS-1-:2];
                    address <= ch2.address[0+:ADDR_BITS];

                    bank_save <= ch2.address[ch2.USER_ADDR_BITS-1-:2];
                    col_save <= ch2.address[0+ADDR_BITS+:COLUMN_BITS];
                    data_save <= write[2] ? ch2.data_write : 'x;

                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    op <= write[2] ? OP_WRITE : OP_READ;
                end
            end
            STATE_ACTIVE: begin
                step <= step + 1'd1;

                if (step == ACTIVE_CMD && op != OP_REFRESH) begin
                    bank <= bank_save;
                    address <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, col_save};
                    address[10] <= 1;  // Auto-precharge
                    data_tx <= data_save;
                    dqm <= (op == OP_READ || ch2.busy) ? 2'b00 : (low_bit ? 2'b01 : 2'b10);
                    cmd <= (op == OP_READ) ? CMD_READ : CMD_WRITE;
                end else if (step == ACTIVE_READY && op == OP_READ) begin
                    if (op == OP_READ) begin
                        if (ch0.busy) ch0.data_read <= low_bit ? dq[15:8] : dq[7:0];
                        else if (ch1.busy) ch1.data_read <= low_bit ? dq[15:8] : dq[7:0];
                        else if (ch2.busy) ch2.data_read <= dq;
                    end
                end else if ((step == ACTIVE_READ && op == OP_READ) || (step == ACTIVE_WRITE && op == OP_WRITE)) begin
                    ch0.busy <= 0;
                    ch1.busy <= 0;
                    state <= STATE_IDLE;
                end else if (step == ACTIVE_READ && op == OP_REFRESH) state <= STATE_IDLE;
                else begin
                    bank <= 'x;
                    address <= 'x;
                    dqm <= 'x;
                    cmd <= CMD_NOOP;
                end
            end
        endcase
    end
endmodule
