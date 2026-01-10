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
    output logic [15:0] audio
);
    localparam MAP_CNT = 32;

    logic cpu_reset;
    logic [4:0] select;
    logic [4:0] chr_off;
    logic [1:0] map_args;
    logic [ADDR_BITS-1:0] chr_mask;
    logic [7:0] cpu_data_out, ppu_data_out;
    logic launcher_buffer_num;
    logic launcher_halt;
    logic launcher_load;
    logic [8:0] launcher_status;

    // Muxed bus signals
    logic [7:0] bus_cpu_data_out[MAP_CNT];
    logic bus_custom_cpu_out[MAP_CNT];
    logic bus_irq[MAP_CNT];
    logic bus_ciram_a10[MAP_CNT];
    logic bus_ciram_ce[MAP_CNT];
    logic [ADDR_BITS-1:0] bus_prg_addr[MAP_CNT];
    logic bus_prg_oe[MAP_CNT];
    logic [ADDR_BITS-1:0] bus_chr_addr[MAP_CNT];
    logic bus_chr_ce[MAP_CNT];
    logic bus_chr_oe[MAP_CNT];
    logic bus_chr_we[MAP_CNT];
    logic [15:0] bus_audio[MAP_CNT];

    map_bus map[MAP_CNT] ();

    launcher launcher (
        .bus(map[0]),
        .buffer_num(launcher_buffer_num),
        .halt(launcher_halt),
        .load_app(launcher_load),
        .status(launcher_status)
    );
    NROM NROM (.bus(map[1]));
    MMC1 MMC1 (.bus(map[2]));
    UxROM UxROM (.bus(map[3]));
    CNROM CNROM (.bus(map[4]));
    VRC6 VRC6 (.bus(map[5]));

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

        // unpack interface array
        assign bus_cpu_data_out[n] = map[n].cpu_data_out;
        assign bus_custom_cpu_out[n] = map[n].custom_cpu_out;
        assign bus_irq[n] = map[n].irq;
        assign bus_ciram_a10[n] = map[n].ciram_a10;
        assign bus_ciram_ce[n] = map[n].ciram_ce;
        assign bus_prg_addr[n] = map[n].prg_addr;
        assign bus_prg_oe[n] = map[n].prg_oe;
        assign bus_chr_addr[n] = map[n].chr_addr;
        assign bus_chr_ce[n] = map[n].chr_ce;
        assign bus_chr_oe[n] = map[n].chr_oe;
        assign bus_chr_we[n] = map[n].chr_we;
        assign bus_audio[n] = map[n].audio;
    end

    // mux for outgoing signals
    assign cpu_oe = bus_prg_oe[select];
    assign ppu_oe = bus_chr_ce[select] && bus_chr_oe[select];
    assign cpu_data = cpu_oe ? (bus_custom_cpu_out[select] ? bus_cpu_data_out[select] : cpu_data_out) : 'z;
    assign irq = bus_irq[select];
    assign audio = bus_audio[select];
    assign ciram_a10 = bus_ciram_a10[select];
    assign ciram_ce = bus_ciram_ce[select];
    assign ppu_data = ppu_oe ? ppu_data_out : 'z;
    assign chr_mask = (chr_off == '0) ? '0 : ADDR_BITS'(1 << chr_off);

    prg_ram prg_ram (
        .clk(clk),
        .ram(ch_prg),
        .oe(bus_prg_oe[select] && !bus_custom_cpu_out[select]),
        .addr(bus_prg_addr[select] & ADDR_BITS'((1 << chr_off) - 5'd1)),
        .data_out(cpu_data_out)
    );

    chr_ram chr_ram (
        .clk(clk),
        .ram(ch_chr),
        .addr(bus_chr_addr[select] | chr_mask),
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
    logic [7:0] prev_cpu_data;

    always_ff @(negedge m2 or posedge cpu_reset) begin
        if (cpu_reset) begin
            select <= '0;
            chr_off <= '0;
            map_args <= '0;
            launcher_buffer_num <= '0;
            launcher_load <= 0;
        end else begin
            launcher_halt <= 0;
            prev_cpu_data <= cpu_data;

            wr_reg_sync   <= {wr_reg_sync[1:0], wr_reg_changed};
            if (wr_reg_sync[1] != wr_reg_sync[2]) begin
                if (wr_reg_addr == REG_MAPPER) begin
                    {map_args, chr_off, pending_select} <= wr_reg[11:0];
                    launcher_load <= 1;
                end else if (wr_reg_addr == REG_LAUNCHER) begin
                    {launcher_halt, launcher_buffer_num} <= wr_reg[1:0];
                end
            end

            if (launcher_load && cpu_data == 'hFF && prev_cpu_data == 'hFC) begin
                select <= pending_select;
                launcher_load <= 0;
            end
        end
    end

    logic [2:0] m2_sync;
    logic [7:0] reset_seq;
    logic [1:0] launcher_active;
    assign cpu_reset = (reset_seq == '1);

    always_ff @(posedge clk) begin
        m2_sync <= {m2_sync[1:0], m2};
        launcher_active <= {launcher_active[0], select == 'd0};

        refresh <= 1'b0;

        if (m2_sync[2:1] == 2'b10) begin
            status_reg <= 32'(launcher_status);
            reset_seq  <= '0;

            // Refresh is performed after the OE cycle is completed.
            if (!launcher_active[1]) refresh <= 1'b1;
        end else if (reset_seq != '1) begin
            reset_seq <= reset_seq + 1'd1;
        end
    end
endmodule
