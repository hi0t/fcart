module sdram #(
    parameter CLK_FREQ = 62_500_000,
    parameter ADDR_BITS = 12,
    parameter COLUMN_BITS = 8,
    parameter BANK_BITS = 2,
    // Mode settings
    parameter CAS_LATENCY = 2,  // 2 or 3 allowed. 3 for >133MHz
    // Timings
    parameter INITIAL_PAUSE_US = 200,
    parameter PRECHARGE_TIME_NS = 15,
    parameter REGISTER_SET_CYCLES = 2,
    parameter REFRESH_TIME_NS = 60,
    parameter REFRESH_INTERVAL_US = 15.6,  // 4K / refresh cycles
    parameter RAS_TO_CAS_TIME_NS = 15,
    parameter WRITE_TIME_CYCLES = 2
) (
    input logic clk,
    input logic read_req,
    input logic write_req,
    input logic [REQ_ADDR_BITS-1:0] address_req,
    input logic [15:0] data_in,
    output logic [15:0] data_out,
    output logic busy,

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
        STATE_PDM_EXIT = 4'd1,
        STATE_PRECHARGE_ALL = 4'd2,
        STATE_SET_MODE = 4'd3,
        STATE_INIT_REFRESH = 4'd4,
        STATE_IDLE = 4'd5,
        STATE_READ = 4'd6,
        STATE_READ_COMPLETE = 4'd7,
        STATE_WRITE = 4'd8,
        STATE_DELAY = 4'd9
    }
        state = STATE_INIT, next_state;

    // Bank width + row width + column width
    localparam REQ_ADDR_BITS = BANK_BITS + ADDR_BITS + COLUMN_BITS;
    localparam INITIAL_PAUSE_CYCLES = uint'(INITIAL_PAUSE_US / 1e6 * CLK_FREQ);
    // The initial pause has the longest delay
    localparam DELAY_WIDTH = $clog2(INITIAL_PAUSE_CYCLES + 1);
    localparam PRECHARGE_CYCLES = uint'(PRECHARGE_TIME_NS / 1e9 * CLK_FREQ);
    localparam REFRESH_CYCLES = uint'(REFRESH_TIME_NS / 1e9 * CLK_FREQ);
    localparam REFRESH_INTERVAL_CYCLES = uint'(REFRESH_INTERVAL_US / 1e6 * CLK_FREQ) + REFRESH_CYCLES;
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
    logic read_prev, write_prev;
    logic [COLUMN_BITS-1:0] col;
    logic [2:0] cmd;

    assign {ras, cas, we} = cmd;
    assign cs = (cmd == CMD_NOOP);
    assign dq = (cmd == CMD_WRITE) ? data_tx : 'z;
    assign dqm = (cmd == CMD_READ || cmd == CMD_WRITE) ? 2'b00 : 2'b11;

    always_ff @(posedge clk) begin
        read_prev  <= read_prev & read_req;
        write_prev <= write_prev & write_req;

        if (refresh_timer > 0) refresh_timer <= refresh_timer - 1'd1;

        case (state)
            STATE_INIT: begin
                refresh_timer <= 0;
                busy <= 0;
                cke <= 0;
                address <= 'x;
                bank <= 'x;
                cmd <= CMD_NOOP;
                delay <= DELAY_WIDTH'(INITIAL_PAUSE_CYCLES - 1);
                next_state <= STATE_PDM_EXIT;
                state <= STATE_DELAY;
            end

            STATE_PDM_EXIT: begin
                cke   <= 1;
                state <= STATE_PRECHARGE_ALL;
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
                if (refresh_timer == 0) begin
                    refresh_timer <= REFRESH_INTERVAL_WIDTH'(REFRESH_INTERVAL_CYCLES);
                    address <= 'x;
                    bank <= 'x;
                    busy <= 0;
                    cmd <= CMD_AUTO_REFRESH;
                    delay <= DELAY_WIDTH'(REFRESH_CYCLES - 1);
                    next_state <= STATE_IDLE;
                    state <= STATE_DELAY;
                end else if ((read_req && !read_prev) || (write_req && !write_prev)) begin
                    read_prev <= read_req;
                    write_prev <= write_req;
                    busy <= 1;
                    // Capture the requested address and data along with the command
                    col <= address_req[COLUMN_BITS-1:0];
                    data_tx <= data_in;

                    address <= address_req[ADDR_BITS+COLUMN_BITS-1:COLUMN_BITS];
                    bank <= address_req[REQ_ADDR_BITS-1:REQ_ADDR_BITS-BANK_BITS];
                    cmd <= CMD_ACTIVATE;
                    delay <= DELAY_WIDTH'(RAS_TO_CAS_CYCLES - 1);
                    state <= STATE_DELAY;
                    next_state <= read_req ? STATE_READ : STATE_WRITE;
                end else begin
                    cmd   <= CMD_NOOP;
                    busy  <= 0;
                    state <= STATE_IDLE;
                end
            end

            STATE_READ: begin
                address <= {2'b01, {ADDR_BITS - COLUMN_BITS - 2{1'b0}}, col};  // Auto-precharge
                cmd <= CMD_READ;
                delay <= DELAY_WIDTH'(CAS_LATENCY - 1);
                next_state <= STATE_READ_COMPLETE;
                state <= STATE_DELAY;
            end

            STATE_READ_COMPLETE: begin
                data_out <= dq;
                state <= STATE_IDLE;
            end

            STATE_WRITE: begin
                address <= {2'b01, {ADDR_BITS - COLUMN_BITS - 2{1'b0}}, col};  // Auto-precharge
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
