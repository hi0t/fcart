module map_mux #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    input logic async_reset,
    sdram_bus.controller ch_prg,
    sdram_bus.controller ch_chr,

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

    input logic [31:0] wr_reg,
    input logic [3:0] wr_reg_addr,
    input logic wr_reg_changed
);

    localparam MAP_CNT = 32;
    map_bus map[MAP_CNT] ();

    loader loader (.bus(map[0]));
    NROM NROM (.bus(map[1]));
    MMC1 MMC1 (.bus(map[2]));
    UxROM UxROM (.bus(map[3]));
    CNROM CNROM (.bus(map[4]));

    logic [4:0] select;
    logic [6:0] map_args;
    logic [4:0] chr_off;
    logic [2:0] wr_reg_sync;
    logic [7:0] cpu_data_out, ppu_data_out;

    // Muxed bus signals
    logic [7:0] bus_cpu_data_out[MAP_CNT];
    logic bus_cpu_oe[MAP_CNT];
    logic bus_irq[MAP_CNT];
    logic bus_ciram_a10[MAP_CNT];
    logic bus_ciram_ce[MAP_CNT];
    logic [ADDR_BITS-1:0] bus_prg_addr[MAP_CNT];
    logic bus_prg_oe[MAP_CNT];
    logic [ADDR_BITS-1:0] bus_chr_addr[MAP_CNT];
    logic bus_chr_ce[MAP_CNT];
    logic bus_chr_oe[MAP_CNT];
    logic bus_chr_we[MAP_CNT];

    genvar n;
    for (n = 0; n < MAP_CNT; n = n + 1) begin
        // mux for incoming signals
        assign map[n].reset = (n == select) ? 1'b0 : 1'b1;
        assign map[n].args = map_args;
        assign map[n].m2 = m2;
        assign map[n].cpu_addr = cpu_addr;
        assign map[n].cpu_data_in = cpu_data;
        assign map[n].cpu_rw = cpu_rw;
        assign map[n].ppu_rd = ppu_rd;
        assign map[n].ppu_wr = ppu_wr;
        assign map[n].ppu_addr = ppu_addr;

        // unpack interface array
        assign bus_cpu_data_out[n] = map[n].cpu_data_out;
        assign bus_cpu_oe[n] = map[n].cpu_oe;
        assign bus_irq[n] = map[n].irq;
        assign bus_ciram_a10[n] = map[n].ciram_a10;
        assign bus_ciram_ce[n] = map[n].ciram_ce;
        assign bus_prg_addr[n] = map[n].prg_addr;
        assign bus_prg_oe[n] = map[n].prg_oe;
        assign bus_chr_addr[n] = map[n].chr_addr;
        assign bus_chr_ce[n] = map[n].chr_ce;
        assign bus_chr_oe[n] = map[n].chr_oe;
        assign bus_chr_we[n] = map[n].chr_we;
    end

    // mux for outgoing signals
    assign cpu_oe = bus_prg_oe[select];
    assign ppu_oe = bus_chr_ce[select] && bus_chr_oe[select];
    assign cpu_data = cpu_oe ? (bus_cpu_oe[select] ? bus_cpu_data_out[select] : cpu_data_out) : 'z;
    assign irq = bus_irq[select];
    assign ciram_a10 = bus_ciram_a10[select];
    assign ciram_ce = bus_ciram_ce[select];
    assign ppu_data = ppu_oe ? ppu_data_out : 'z;

    assign chr_off = map_args[4:0];

    prg_ram prg_ram (
        .clk(clk),
        .ram(ch_prg),
        .oe(bus_prg_oe[select] && !bus_cpu_oe[select]),
        .addr(bus_prg_addr[select] & ADDR_BITS'((1 << chr_off) - 1)),
        .data_out(cpu_data_out)
    );

    chr_ram chr_ram (
        .clk(clk),
        .ram(ch_chr),
        .addr(bus_chr_addr[select] | ADDR_BITS'(1 << chr_off)),
        .data_in(ppu_data),
        .data_out(ppu_data_out),
        .ce(bus_chr_ce[select]),
        .oe(bus_chr_oe[select]),
        .we(bus_chr_we[select])
    );

    always_ff @(posedge m2 or posedge async_reset) begin
        if (async_reset) begin
            select   <= '0;
            map_args <= '0;
        end else begin
            wr_reg_sync <= {wr_reg_sync[1:0], wr_reg_changed};
            if (wr_reg_sync[1] != wr_reg_sync[2] && wr_reg_addr == 0) begin
                {map_args, select} <= wr_reg[11:0];
            end
        end
    end
endmodule
