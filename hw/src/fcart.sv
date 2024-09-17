`include "mappers/map.svh"

module fcart (
    input logic CLK,

    // SDIO interface
    input logic SDIO_CLK,
    inout wire  SDIO_CMD,

    // SDRAM chip interface
    inout wire [15:0] SDRAM_DQ,
    output logic [12:0] SDRAM_ADDR,
    output logic [1:0] SDRAM_BA,
    output logic SDRAM_CLK,
    output logic SDRAM_CKE,
    output logic SDRAM_CS,
    output logic SDRAM_RAS,
    output logic SDRAM_CAS,
    output logic SDRAM_WE,
    output logic [1:0] SDRAM_DQM,

    input logic M2,
    input logic [14:0] CPU_ADDR,
    inout wire [7:0] CPU_DATA,
    input logic CPU_RW,
    input logic ROM_CE,
    //output logic IRQ,
    input logic PPU_RD,
    input logic PPU_WR,
    output logic CIRAM_A10,
    output logic CIRAM_CE,
    input logic [13:0] PPU_ADDR,
    inout wire [7:0] PPU_DATA,
    output logic CPU_DIR,
    output logic PPU_DIR
);
    localparam RAM_ADDR_BITS = 24;

    logic refresh;
    logic sdram_pll;
    logic pll_locked;
    map::in map_in;
    map::out map_out;
    logic [7:0] prg_data;
    logic [7:0] chr_data;
    sdram_bus #(.ADDR_BITS(RAM_ADDR_BITS - 1)) ram_ch0 (), ram_ch1 ();
    sdio_bus sbus (.clk(SDIO_CLK));

    assign CPU_DIR = !ROM_CE && CPU_RW;
    assign PPU_DIR = map_out.ciram_ce && !PPU_RD;
    assign CPU_DATA = CPU_DIR ? prg_data : 'z;
    assign PPU_DATA = PPU_DIR ? chr_data : 'z;
    assign map_in.m2 = M2;
    assign map_in.cpu_addr = CPU_ADDR;
    assign map_in.cpu_data = CPU_DATA;
    assign map_in.cpu_rw = CPU_RW;
    assign map_in.rom_ce = ROM_CE;
    assign map_in.ppu_addr = PPU_ADDR;
    assign map_in.ppu_data = PPU_DATA;
    assign map_in.ppu_rd = PPU_RD;
    assign map_in.ppu_wr = PPU_WR;
    assign CIRAM_A10 = map_out.ciram_a10;
    assign CIRAM_CE = map_out.ciram_ce;

    rom rom (
        .clk(sdram_pll),
        .in(map_in),
        .out(map_out),
        .prg_ram(ram_ch0.device),
        .chr_ram(ram_ch1.device),
        .sdio(sbus.device),
        .prg_data(prg_data),
        .chr_data(chr_data)
    );

    pll pll (
        .inclk0(CLK),
        .c0(sdram_pll),
        .locked(pll_locked)
    );

    sdram #(
        .ADDR_BITS(13),
        .COLUMN_BITS(9),
        .REFRESH_INTERVAL(1040)
    ) ram (
        .clk(sdram_pll),
        .ch0(ram_ch0.host),
        .ch1(ram_ch1.host),
        .init(pll_locked),
        .refresh(refresh),
        .SDRAM_CKE(SDRAM_CKE),
        .SDRAM_CS(SDRAM_CS),
        .SDRAM_ADDR(SDRAM_ADDR),
        .SDRAM_BA(SDRAM_BA),
        .SDRAM_DQ(SDRAM_DQ),
        .SDRAM_RAS(SDRAM_RAS),
        .SDRAM_CAS(SDRAM_CAS),
        .SDRAM_WE(SDRAM_WE),
        .SDRAM_DQM(SDRAM_DQM)
    );

    sdio_cmd sdio (
        .cmd(SDIO_CMD),
        .bus(sbus)
    );

    // TODO connect SDRAM_CLK directly to PLL pin
    altddio_out #(
        .extend_oe_disable("OFF"),
        .intended_device_family("Cyclone 10 LP"),
        .invert_output("OFF"),
        .lpm_hint("UNUSED"),
        .lpm_type("altddio_out"),
        .oe_reg("UNREGISTERED"),
        .power_up_high("OFF"),
        .width(1)
    ) sdramclk_ddr (
        .datain_h(1'b0),
        .datain_l(1'b1),
        .outclock(sdram_pll),
        .dataout(SDRAM_CLK),
        .aclr(1'b0),
        .aset(1'b0),
        .oe(1'b1),
        .outclocken(1'b1),
        .sclr(1'b0),
        .sset(1'b0)
    );

    logic [2:0][13:0] addr_sync;
    always_ff @(posedge sdram_pll) begin
        addr_sync <= {addr_sync[1:0], PPU_ADDR};
        // Before reading, the PPU sets a new address.
        // This event will fall into the update window,
        // which will ensure that it does not overlap with access to the PPU memory.
        refresh   <= addr_sync[2] != addr_sync[1];
    end
endmodule
