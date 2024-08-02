module sdram #(
    parameter ADDR_BITS = 12,
    parameter COLUMN_BITS = 8,
    parameter BANK_BITS = 2,
    parameter REFRESH_INTERVAL = 1950  // tREF / 4K(8K) 15.6E-6 * FREQ
) (
    input logic clk,
    input logic init,
    sdram_bus.host ch_16bit,
    sdram_bus.host ch0_8bit,
    sdram_bus.host ch1_8bit,

    // SDRAM chip interface
    output logic cke,
    output logic cs,
    output logic [ADDR_BITS-1:0] address,
    output logic [BANK_BITS-1:0] bank,
    inout wire [15:0] dq,
    output logic ras,
    output logic cas,
    output logic we,
    output logic [1:0] dqm
);
    typedef byte unsigned uint8;
    typedef shortint unsigned uint16;

    localparam uint16 INITIAL_PAUSE = 25_000;  // 200E-6 * FREQ
    localparam uint8 PRECHARGE_PERIOD = 2;  // tRP 15E-9 * FREQ
    localparam uint8 REGISTER_SET = 2;  // tRSC clocks
    localparam uint8 CAS_LATENCY = 2;  // 2 or 3 clocks allowed. 3 for >133MHz
    localparam uint8 ACTIVE_TO_RW = 2;  // tRCD 15E-9 * FREQ
    localparam uint8 READ_PERIOD = 8;  // tRAS + tRP
    localparam uint8 WRITE_PERIOD = 9;  // tRAS + tRP + tWR

    // configure steps
    localparam CONFIGURE_PRECHARGE = 0;
    localparam CONFIGURE_SET_MODE = CONFIGURE_PRECHARGE + PRECHARGE_PERIOD;
    localparam CONFIGURE_REFRESH_1 = CONFIGURE_SET_MODE + REGISTER_SET;
    // READ_PERIOD cover the refresh period
    localparam CONFIGURE_REFRESH_2 = CONFIGURE_REFRESH_1 + READ_PERIOD;
    localparam CONFIGURE_END = CONFIGURE_REFRESH_2 + READ_PERIOD;

    // active steps
    localparam ACTIVE_START = uint8'(1);
    localparam ACTIVE_RW = ACTIVE_START + ACTIVE_TO_RW;
    localparam ACTIVE_READY = ACTIVE_RW + CAS_LATENCY + uint8'(1);

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

    localparam CMD_NOOP = 3'b111;
    localparam CMD_ACTIVATE = 3'b011;
    localparam CMD_MODE_REGISTER_SET = 3'b000;
    localparam CMD_AUTO_REFRESH = 3'b001;
    localparam CMD_READ = 3'b101;
    localparam CMD_WRITE = 3'b100;
    localparam CMD_PRECHARGE = 3'b010;

    logic [2:0] cmd;
    logic [COLUMN_BITS-1:0] col_save;
    logic [1:0] mask;
    logic low_bit;
    logic [15:0] data_tx;
    logic [2:0] read_ch, write_ch, read_prev_ch, write_prev_ch;
    logic  force_refresh;
    uint8  step = 0;
    uint16 timer = 0;

    assign cke = 1;
    assign {ras, cas, we} = cmd;
    assign cs = (cmd == CMD_NOOP);
    assign dq = (cmd == CMD_WRITE) ? data_tx : 'z;
    assign read_ch = {ch1_8bit.read_buf, ch0_8bit.read_buf, ch_16bit.read_buf};
    assign write_ch = {ch1_8bit.write_buf, ch0_8bit.write_buf, ch_16bit.write_buf};
    assign force_refresh = ch1_8bit.refresh_buf || ch0_8bit.refresh_buf || ch_16bit.refresh_buf;

    always_ff @(posedge clk) begin
        timer <= timer + 1'd1;

        read_prev_ch <= read_prev_ch & read_ch;
        write_prev_ch <= write_prev_ch & write_ch;

        case (state)
            STATE_POWERUP: begin
                case (timer)
                    0: begin
                        address <= 'x;
                        bank <= 'x;
                        cmd <= CMD_NOOP;
                    end
                    INITIAL_PAUSE: begin
                        if (init) begin
                            step  <= 0;
                            state <= STATE_CONFIGURE;
                        end else timer <= INITIAL_PAUSE;
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
                        address <= 'x;
                        bank <= 'x;
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
                step <= ACTIVE_START;
                dqm  <= 2'b11;
                cmd  <= CMD_NOOP;

                if (timer >= REFRESH_INTERVAL || (force_refresh && (timer >= REFRESH_INTERVAL / 2))) begin
                    timer <= 0;
                    address <= 'x;
                    bank <= 'x;
                    cmd <= CMD_AUTO_REFRESH;
                    op <= OP_REFRESH;
                    state <= STATE_ACTIVE;
                end else if ((read_ch[0] && !read_prev_ch[0]) || (write_ch[0] && !write_prev_ch[0])) begin
                    read_prev_ch[0] <= read_ch[0];
                    write_prev_ch[0] <= write_ch[0];
                    ch_16bit.busy <= 1;

                    address <= ch_16bit.address[0+:ADDR_BITS];  // Row
                    col_save <= ch_16bit.address[ADDR_BITS+:COLUMN_BITS];  //Column
                    bank <= ch_16bit.address[$bits(ch_16bit.address)-1-:BANK_BITS];
                    data_tx <= ch_16bit.data_write;
                    mask <= 2'b00;

                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    op <= read_ch[0] ? OP_READ : OP_WRITE;
                end else if ((read_ch[1] && !read_prev_ch[1]) || (write_ch[1] && !write_prev_ch[1])) begin
                    read_prev_ch[1] <= read_ch[1];
                    write_prev_ch[1] <= write_ch[1];
                    ch0_8bit.busy <= 1;

                    address <= ch0_8bit.address[1+:ADDR_BITS];
                    col_save <= ch0_8bit.address[1+ADDR_BITS+:COLUMN_BITS];
                    bank <= ch0_8bit.address[$bits(ch0_8bit.address)-1-:BANK_BITS];
                    data_tx <= {ch0_8bit.data_write, ch0_8bit.data_write};
                    mask <= {write_ch[1] & !ch0_8bit.address[0], write_ch[1] & ch0_8bit.address[0]};
                    low_bit <= ch0_8bit.address[0];

                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    op <= read_ch[1] ? OP_READ : OP_WRITE;
                end else if ((read_ch[2] && !read_prev_ch[2]) || (write_ch[2] && !write_prev_ch[2])) begin
                    read_prev_ch[2] <= read_ch[2];
                    write_prev_ch[2] <= write_ch[2];
                    ch1_8bit.busy <= 1;

                    address <= ch1_8bit.address[1+:ADDR_BITS];
                    col_save <= ch1_8bit.address[1+ADDR_BITS+:COLUMN_BITS];
                    bank <= ch1_8bit.address[$bits(ch1_8bit.address)-1-:BANK_BITS];
                    data_tx <= {ch1_8bit.data_write, ch1_8bit.data_write};
                    mask <= {write_ch[2] & !ch1_8bit.address[0], write_ch[2] & ch1_8bit.address[0]};
                    low_bit <= ch1_8bit.address[0];

                    cmd <= CMD_ACTIVATE;
                    state <= STATE_ACTIVE;
                    op <= read_ch[2] ? OP_READ : OP_WRITE;
                end
            end
            STATE_ACTIVE: begin
                step <= step + 1'd1;

                if (step == ACTIVE_RW && op != OP_REFRESH) begin
                    address <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, col_save};
                    address[10] <= 1;  // Auto-precharge
                    dqm <= mask;
                end

                // verilog_format: off
                case ({step, op})
                    {ACTIVE_RW, OP_READ} : cmd <= CMD_READ;
                    {ACTIVE_RW, OP_WRITE} : cmd <= CMD_WRITE;
                    {ACTIVE_READY, OP_READ} : begin
                        if (ch_16bit.busy) ch_16bit.data_read <= dq;
                        else if (ch0_8bit.busy)
                            ch0_8bit.data_read <= low_bit ? dq[15:8] : dq[7:0];
                        else if (ch1_8bit.busy)
                            ch1_8bit.data_read <= low_bit ? dq[15:8] : dq[7:0];
                    end
                    {READ_PERIOD, OP_READ}, {WRITE_PERIOD, OP_WRITE} : begin
                        state <= STATE_IDLE;
                        ch_16bit.busy <= 0;
                        ch0_8bit.busy <= 0;
                        ch1_8bit.busy <= 0;
                    end
                    {READ_PERIOD, OP_REFRESH} : state <= STATE_IDLE;
                    default: begin
                        address <= 'x;
                        cmd <= CMD_NOOP;
                    end
                endcase
                // verilog_format: on
            end
        endcase
    end
endmodule
