module sdram #(
    parameter CLK_FREQ = 62_500_000,
    parameter ADDR_BITS = 12,
    parameter COLUMN_BITS = 8,
    parameter BANK_BITS = 2,
    // Mode settings
    parameter CAS_LATENCY = 2,  // 2 or 3 allowed. 3 for >133MHz
    // Timings
    parameter INITIAL_PAUSE_US = 200,
    parameter PRECHARGE_TIME_NS = 15,  // tRP
    parameter REGISTER_SET_CYCLES = 2,  // tRSC
    parameter REFRESH_TIME_NS = 60,  // tRC
    parameter REFRESH_INTERVAL_US = 15.6,  // tREF 4K / refresh cycles
    parameter RAS_TO_CAS_TIME_NS = 15,  // tRCD
    parameter WRITE_TIME_CYCLES = 2  // tWR
) (
    input logic clk,
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
    typedef int unsigned uint;

    enum logic [3:0] {
        STATE_INIT = 4'd0,
        STATE_PRECHARGE_ALL = 4'd1,
        STATE_SET_MODE = 4'd2,
        STATE_INIT_REFRESH = 4'd3,
        STATE_IDLE = 4'd4,
        STATE_READ = 4'd5,
        STATE_READ_COMPLETE = 4'd6,
        STATE_WRITE = 4'd7,
        STATE_DELAY = 4'd8
    }
        state = STATE_INIT, next_state;

    // Bank width + row width + column width
    localparam RAM_ADDR_BITS = BANK_BITS + ADDR_BITS + COLUMN_BITS;
    localparam INITIAL_PAUSE_CYCLES = uint'(INITIAL_PAUSE_US / 1e6 * CLK_FREQ);
    // The initial pause has the longest delay
    localparam DELAY_WIDTH = $clog2(INITIAL_PAUSE_CYCLES + 1);
    localparam PRECHARGE_CYCLES = uint'(PRECHARGE_TIME_NS / 1e9 * CLK_FREQ);
    localparam REFRESH_CYCLES = uint'(REFRESH_TIME_NS / 1e9 * CLK_FREQ);
    localparam REFRESH_INTERVAL_CYCLES = uint'(REFRESH_INTERVAL_US / 1e6 * CLK_FREQ);
    localparam REFRESH_INTERVAL_WIDTH = $clog2(REFRESH_INTERVAL_CYCLES + 1);
    localparam RAS_TO_CAS_CYCLES = uint'(RAS_TO_CAS_TIME_NS / 1e9 * CLK_FREQ);

    localparam CMD_NOOP = 3'b111;
    localparam CMD_ACTIVATE = 3'b011;
    localparam CMD_MODE_REGISTER_SET = 3'b000;
    localparam CMD_AUTO_REFRESH = 3'b001;
    localparam CMD_READ = 3'b101;
    localparam CMD_WRITE = 3'b100;
    localparam CMD_PRECHARGE = 3'b010;

    logic [DELAY_WIDTH-1:0] delay;
    logic [REFRESH_INTERVAL_WIDTH-1:0] refresh_timer;
    logic [15:0] data_tx;
    logic [2:0] read_ch, write_ch, read_prev_ch, write_prev_ch;
    logic [1:0][2:0] read_ch_buffered, write_ch_buffered;
    logic [COLUMN_BITS-1:0] col;
    logic [2:0] cmd;

    assign cke = 1;
    assign {ras, cas, we} = cmd;
    assign cs = (cmd == CMD_NOOP);
    assign dq = (cmd == CMD_WRITE) ? data_tx : 'z;
    assign read_ch = read_ch_buffered[1];
    assign write_ch = write_ch_buffered[1];

    always_ff @(posedge clk) begin
        // Synchronization of signals from other clock domains.
        read_ch_buffered <= {read_ch_buffered[0], {ch1_8bit.read, ch0_8bit.read, ch_16bit.read}};
        write_ch_buffered <= {
            write_ch_buffered[0], {ch1_8bit.write, ch0_8bit.write, ch_16bit.write}
        };

        read_prev_ch <= read_prev_ch & read_ch;
        write_prev_ch <= write_prev_ch & write_ch;

        if (refresh_timer > 0) refresh_timer <= refresh_timer - 1'd1;

        case (state)
            STATE_INIT: begin
                refresh_timer <= 0;
                address <= 'x;
                bank <= 'x;
                cmd <= CMD_NOOP;
                delay <= DELAY_WIDTH'(INITIAL_PAUSE_CYCLES - 1);
                next_state <= STATE_PRECHARGE_ALL;
                state <= STATE_DELAY;
            end

            STATE_PRECHARGE_ALL: begin
                address[10] <= 1'b1;  // precharge all banks
                cmd <= CMD_PRECHARGE;
                delay <= DELAY_WIDTH'(PRECHARGE_CYCLES - 1);
                next_state <= STATE_SET_MODE;
                state <= STATE_DELAY;
            end

            STATE_SET_MODE: begin
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
                delay <= DELAY_WIDTH'(REGISTER_SET_CYCLES - 1);
                next_state <= STATE_INIT_REFRESH;
                state <= STATE_DELAY;
            end

            STATE_INIT_REFRESH: begin
                address <= 'x;
                bank <= 'x;
                cmd <= CMD_AUTO_REFRESH;
                delay <= DELAY_WIDTH'(REFRESH_CYCLES - 1);
                next_state <= STATE_IDLE;
                state <= STATE_DELAY;
                // The second auto-refresh cycle will happen in idle status, because timer is zero.
            end

            STATE_IDLE: begin
                ch_16bit.busy <= 0;
                ch0_8bit.busy <= 0;
                ch1_8bit.busy <= 0;
                dqm <= 2'b11;

                if (refresh_timer == 0) begin
                    refresh_timer <= REFRESH_INTERVAL_WIDTH'(REFRESH_INTERVAL_CYCLES);
                    address <= 'x;
                    bank <= 'x;
                    cmd <= CMD_AUTO_REFRESH;
                    delay <= DELAY_WIDTH'(REFRESH_CYCLES - 1);
                    next_state <= STATE_IDLE;
                    state <= STATE_DELAY;
                end else if ((read_ch[0] && !read_prev_ch[0]) || (write_ch[0] && !write_prev_ch[0])) begin
                    read_prev_ch[0] <= read_ch[0];
                    write_prev_ch[0] <= write_ch[0];
                    ch_16bit.busy <= 1;

                    address <= ch_16bit.address[0+:ADDR_BITS];  // Row
                    col <= ch_16bit.address[ADDR_BITS+:COLUMN_BITS];  //Column
                    bank <= ch_16bit.address[RAM_ADDR_BITS-1-:BANK_BITS];
                    data_tx <= ch_16bit.data_write;
                    dqm <= 2'b00;

                    cmd <= CMD_ACTIVATE;
                    delay <= DELAY_WIDTH'(RAS_TO_CAS_CYCLES - 1);
                    state <= STATE_DELAY;
                    next_state <= read_ch[0] ? STATE_READ : STATE_WRITE;
                end else if ((read_ch[1] && !read_prev_ch[1]) || (write_ch[1] && !write_prev_ch[1])) begin
                    read_prev_ch[1] <= read_ch[1];
                    write_prev_ch[1] <= write_ch[1];
                    ch0_8bit.busy <= 1;

                    address <= ch0_8bit.address[1+:ADDR_BITS];
                    col <= ch0_8bit.address[1+ADDR_BITS+:COLUMN_BITS];
                    bank <= ch0_8bit.address[RAM_ADDR_BITS-:BANK_BITS];
                    data_tx <= {ch0_8bit.data_write, ch0_8bit.data_write};
                    dqm <= {write_ch[1] & ~ch0_8bit.address[0], write_ch[1] & ch0_8bit.address[0]};

                    cmd <= CMD_ACTIVATE;
                    delay <= DELAY_WIDTH'(RAS_TO_CAS_CYCLES - 1);
                    state <= STATE_DELAY;
                    next_state <= read_ch[1] ? STATE_READ : STATE_WRITE;
                end else if ((read_ch[2] && !read_prev_ch[2]) || (write_ch[2] && !write_prev_ch[2])) begin
                    read_prev_ch[2] <= read_ch[2];
                    write_prev_ch[2] <= write_ch[2];
                    ch1_8bit.busy <= 1;

                    address <= ch1_8bit.address[1+:ADDR_BITS];
                    col <= ch1_8bit.address[1+ADDR_BITS+:COLUMN_BITS];
                    bank <= ch1_8bit.address[RAM_ADDR_BITS-:BANK_BITS];
                    data_tx <= {ch1_8bit.data_write, ch1_8bit.data_write};
                    dqm <= {write_ch[2] & ~ch1_8bit.address[0], write_ch[2] & ch1_8bit.address[0]};

                    cmd <= CMD_ACTIVATE;
                    delay <= DELAY_WIDTH'(RAS_TO_CAS_CYCLES - 1);
                    state <= STATE_DELAY;
                    next_state <= read_ch[2] ? STATE_READ : STATE_WRITE;
                end else begin
                    cmd   <= CMD_NOOP;
                    state <= STATE_IDLE;
                end
            end

            STATE_READ: begin
                address <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, col};
                address[10] <= 1;  // Auto-precharge
                cmd <= CMD_READ;
                delay <= DELAY_WIDTH'(CAS_LATENCY - 1);
                next_state <= STATE_READ_COMPLETE;
                state <= STATE_DELAY;
            end

            STATE_READ_COMPLETE: begin
                if (ch_16bit.busy) ch_16bit.data_read <= dq;
                else if (ch0_8bit.busy)
                    ch0_8bit.data_read <= ch0_8bit.address[0] ? dq[15:8] : dq[7:0];
                else if (ch1_8bit.busy)
                    ch1_8bit.data_read <= ch1_8bit.address[0] ? dq[15:8] : dq[7:0];
                state <= STATE_IDLE;
            end

            STATE_WRITE: begin
                address <= {{ADDR_BITS - COLUMN_BITS{1'b0}}, col};
                address[10] <= 1;  // Auto-precharge
                cmd <= CMD_WRITE;
                delay <= DELAY_WIDTH'(WRITE_TIME_CYCLES - 1);
                next_state <= STATE_IDLE;
                state <= STATE_DELAY;
            end

            STATE_DELAY: begin
                if (delay > 0) delay <= delay - 1'd1;
                else state <= next_state;
                cmd <= CMD_NOOP;
            end

            default: state <= STATE_INIT;
        endcase
    end
endmodule
