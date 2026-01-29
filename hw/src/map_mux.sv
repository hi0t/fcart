module map_mux #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    sdram_bus.controller ch_prg,
    sdram_bus.controller ch_chr,
    output logic refresh,

    // Cart interface
    input logic m2,
    input logic [15:0] cpu_addr,
    inout wire [7:0] cpu_data,
    input logic cpu_rw,
    output logic irq,
    input logic ppu_rd,
    input logic ppu_wr,
    output logic ciram_a10,
    output logic ciram_ce,
    input logic [13:0] ppu_addr,
    inout wire [7:0] ppu_data,

    output logic cpu_oe,
    output logic ppu_oe,

    input logic [11:0] wr_reg,
    input logic [3:0] wr_reg_addr,
    input logic wr_reg_changed,
    output logic [31:0] status_reg,
    output logic [15:0] audio,
    input logic [7:0] joy1
);
    // SDRAM mapping
    // PRG ROM:       ........ dynamic size
    // CHR ROM:       ........ dynamic size
    // CHR RAM:       ........ dynamic size
    // SAVES STATES:  11111010 7D0000 32KB
    // LAUNCHER VRAM: 11111011 7D8000 32KB
    // CPU WRAM:      111111.. 7E0000 128KB
    localparam SST_MASK = {8'b11111010, {ADDR_BITS - 8{1'b0}}};
    localparam LAUNCHER_MASK = {8'b11111011, {ADDR_BITS - 8{1'b0}}};
    localparam WRAM_MASK = {6'b111111, {ADDR_BITS - 6{1'b0}}};

    localparam MAP_CNT = 32;

    typedef struct packed {
        logic ingame_menu;
        logic restore_app;
        logic start_app;
        logic buffer_num;
    } launcher_ctrl_t;

    logic cpu_reset;
    logic [4:0] select_reg, select;
    logic [1:0] map_args;
    logic [ADDR_BITS-1:0] prg_mask, chr_mask;
    logic [7:0] cpu_data_out, ppu_data_out;
    launcher_ctrl_t launcher_ctrl;
    logic [1:0] launcher_status;
    logic video_enable;
    logic reset_hijack;
    logic nmi_hijack;
    logic [8:0] st_rec_addr;
    logic [7:0] st_rec_data;

    // Muxed bus signals
    logic [7:0] bus_cpu_data_out[MAP_CNT];
    logic bus_cpu_data_oe[MAP_CNT];
    logic bus_irq[MAP_CNT];
    logic bus_ciram_a10[MAP_CNT];
    logic bus_ciram_ce[MAP_CNT];
    logic [ADDR_BITS-1:0] bus_prg_addr[MAP_CNT];
    logic bus_prg_oe[MAP_CNT];
    logic bus_prg_we[MAP_CNT];
    logic bus_wram_ce[MAP_CNT];
    logic [ADDR_BITS-1:0] bus_chr_addr[MAP_CNT];
    logic bus_chr_ce[MAP_CNT];
    logic bus_chr_oe[MAP_CNT];
    logic bus_chr_we[MAP_CNT];
    logic [15:0] bus_audio[MAP_CNT];

    map_bus map[MAP_CNT] ();

    state_recorder recorder (
        .reset(select == '0 || cpu_reset),
        .m2(m2),
        .cpu_addr(cpu_addr),
        .cpu_data(cpu_data),
        .cpu_rw(cpu_rw),
        .read_addr(st_rec_addr),
        .read_data(st_rec_data)
    );

    launcher launcher (
        .bus(map[0]),
        .ctrl(launcher_ctrl),
        .status(launcher_status),
        .st_rec_addr(st_rec_addr),
        .st_rec_data(st_rec_data)
    );
    NROM NROM (.bus(map[1]));
    MMC1 MMC1 (.bus(map[2]));
    UxROM UxROM (.bus(map[3]));
    CNROM CNROM (.bus(map[4]));
    VRC6 VRC6 (.bus(map[5]));
    AxROM AxROM (.bus(map[6]));

    // Detect the exact cycle when interrupt is read to switch mappers instantaneously
    assign reset_hijack = launcher_ctrl.start_app && cpu_addr == 'hFFFC && cpu_rw;
    assign nmi_hijack = (launcher_ctrl.ingame_menu || launcher_status[1]) && cpu_addr == 'hFFFA && cpu_rw;
    assign select = (reset_hijack || nmi_hijack) ? pending_select : select_reg;
    assign video_enable = launcher_status[0] && !cpu_reset && !launcher_ctrl.start_app;

    genvar n;
    for (n = 0; n < MAP_CNT; n = n + 1) begin
        // mux for incoming signals
        assign map[n].reset = (n != select) || cpu_reset;
        assign map[n].m2 = m2;
        assign map[n].cpu_addr = cpu_addr;
        assign map[n].cpu_data_in = cpu_data;
        assign map[n].cpu_rw = cpu_rw;
        assign map[n].ppu_rd = ppu_rd;
        assign map[n].ppu_wr = ppu_wr;
        assign map[n].ppu_addr = ppu_addr;

        assign map[n].mirroring = map_args[0];
        assign map[n].chr_ram = map_args[1];

        assign map[n].sst_enable = (select == '0);

        // unpack interface array
        assign bus_cpu_data_out[n] = map[n].cpu_data_out;
        assign bus_cpu_data_oe[n] = map[n].cpu_data_oe;
        assign bus_irq[n] = map[n].irq;
        assign bus_ciram_a10[n] = map[n].ciram_a10;
        assign bus_ciram_ce[n] = map[n].ciram_ce;
        assign bus_prg_addr[n] = map[n].prg_addr;
        assign bus_prg_oe[n] = map[n].prg_oe;
        assign bus_prg_we[n] = map[n].prg_we;
        assign bus_wram_ce[n] = map[n].wram_ce;
        assign bus_chr_addr[n] = map[n].chr_addr;
        assign bus_chr_ce[n] = map[n].chr_ce;
        assign bus_chr_oe[n] = map[n].chr_oe;
        assign bus_chr_we[n] = map[n].chr_we;
        assign bus_audio[n] = map[n].audio;
    end

    // mux for outgoing signals
    // M2 gating is required to correctly coordinate bidirectional level shifters
    assign cpu_oe = bus_prg_oe[select] && m2;
    assign ppu_oe = bus_chr_ce[select] && bus_chr_oe[select];
    assign cpu_data = cpu_oe ? (bus_cpu_data_oe[select] ? bus_cpu_data_out[select] : cpu_data_out) : 'z;
    assign irq = bus_irq[select];
    assign audio = bus_audio[select];
    assign ciram_a10 = bus_ciram_a10[select];
    assign ciram_ce = bus_ciram_ce[select];
    assign ppu_data = ppu_oe ? (video_enable || select != 0 ? ppu_data_out : '0) : 'z;

    prg_ram prg_ram (
        .clk(clk),
        .ram(ch_prg),
        .refresh(refresh),
        .addr(
            bus_wram_ce[select] ?
            (bus_prg_addr[select] | WRAM_MASK) :
            (select == '0) ? (bus_prg_addr[select] | SST_MASK) :
            (bus_prg_addr[select] & prg_mask)
        ),
        .data_in(cpu_data),
        .data_out(cpu_data_out),
        .oe(bus_prg_oe[select] && m2 && !bus_cpu_data_oe[select]),
        .we(bus_prg_we[select] && m2)
    );

    chr_ram chr_ram (
        .clk(clk),
        .ram(ch_chr),
        .addr(bus_chr_addr[select] | ((select == '0) ? LAUNCHER_MASK : chr_mask)),
        .data_in(ppu_data),
        .data_out(ppu_data_out),
        .ce(bus_chr_ce[select]),
        .oe(bus_chr_oe[select]),
        .we(bus_chr_we[select])
    );

    localparam REG_MAPPER = 4'd0;
    localparam REG_LAUNCHER = 4'd1;

    logic [2:0] wr_reg_sync;
    logic [4:0] pending_select;

    always_ff @(negedge m2 or posedge cpu_reset) begin
        if (cpu_reset) begin
            select_reg <= '0;
            prg_mask <= '0;
            chr_mask <= '0;
            map_args <= '0;
            launcher_ctrl <= '0;
        end else begin
            wr_reg_sync <= {wr_reg_sync[1:0], wr_reg_changed};
            if (wr_reg_sync[1] != wr_reg_sync[2]) begin
                if (wr_reg_addr == REG_MAPPER) begin
                    pending_select <= wr_reg[4:0];
                    map_args <= wr_reg[11:10];
                    prg_mask <= ADDR_BITS'((1 << wr_reg[9:5]) - 5'd1);
                    chr_mask <= ADDR_BITS'(1 << wr_reg[9:5]);
                end else if (wr_reg_addr == REG_LAUNCHER) begin
                    launcher_ctrl <= wr_reg[3:0];
                end
            end

            // Launch game
            if (reset_hijack) begin
                select_reg <= pending_select;
                launcher_ctrl.start_app <= 0;
            end

            // Enter/Exit menu
            if (nmi_hijack) begin
                select_reg <= pending_select;
                if (launcher_ctrl.restore_app) begin
                    launcher_ctrl.restore_app <= 0;
                end
            end
            if (launcher_ctrl.ingame_menu && cpu_addr == 'hFFFB && cpu_rw) begin
                launcher_ctrl.ingame_menu <= 0;
            end
        end
    end

    logic [2:0] m2_sync;
    logic [7:0] reset_seq;
    assign cpu_reset = (reset_seq == '1);

    always_ff @(posedge clk) begin
        m2_sync <= {m2_sync[1:0], m2};

        if (m2_sync[2:1] == 2'b10) begin
            status_reg <= {23'd0, launcher_status[0], joy1};
            reset_seq  <= '0;
        end else if (reset_seq != '1) begin
            reset_seq <= reset_seq + 1'd1;
        end

        status_reg[9] <= (reset_seq == '1);  // Indicate reset in progress
    end
endmodule
