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
    //input logic PPU_WR,
    output logic CIRAM_A10,
    output logic CIRAM_CE,
    input logic [13:0] PPU_ADDR,
    inout wire [7:0] PPU_DATA,
    output logic CPU_DIR,
    output logic PPU_DIR
);
    localparam RAM_ADDR_BITS = 24;

    logic cpu_read;
    logic ppu_read;
    logic loading;
    logic refresh;
    logic sdram_pll;
    logic pll_locked;
    logic [7:0] cpu_data, ppu_data;

    sdram_bus #(.ADDR_BITS(RAM_ADDR_BITS - 1))
        fc_prg (), fc_chr (), api_prg (), api_chr (), ram_ch0 (), ram_ch1 ();

    assign cpu_read  = !ROM_CE && CPU_RW && M2;
    assign ppu_read  = CIRAM_CE && !PPU_RD;
    assign CPU_DATA  = cpu_read ? cpu_data : 'z;
    assign PPU_DATA  = ppu_read ? ppu_data : 'z;
    assign CPU_DIR   = cpu_read;
    assign PPU_DIR   = ppu_read;
    assign CIRAM_CE  = !PPU_ADDR[13];
    assign CIRAM_A10 = PPU_ADDR[10];

    prg_rom #(
        .ADDR_BITS(RAM_ADDR_BITS)
    ) prg_rom (
        .clk(sdram_pll),
        .ram(fc_prg.device),
        .m2(M2),
        .cpu_rw(CPU_RW),
        .rom_ce(ROM_CE),
        .addr(CPU_ADDR),
        .data(cpu_data)
    );

    chr_rom #(
        .ADDR_BITS(RAM_ADDR_BITS)
    ) chr_rom (
        .clk(sdram_pll),
        .ram(fc_chr.device),
        .refresh(refresh),
        .ppu_rd(PPU_RD),
        .ciram_ce(CIRAM_CE),
        .addr(PPU_ADDR[12:0]),
        .data(ppu_data)
    );

    pll pll (
        .inclk0(CLK),
        .c0(sdram_pll),
        .locked(pll_locked)
    );

    sdram_arbiter arbiter (
        .api_active(loading),
        .api_prg(api_prg.host),
        .api_chr(api_chr.host),
        .fc_prg(fc_prg.host),
        .fc_chr(fc_chr.host),
        .ch0(ram_ch0.device),
        .ch1(ram_ch1.device)
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

    sdio_bus sbus (.clk(SDIO_CLK));
    sdio sdio (
        .cmd_sdio(SDIO_CMD),
        .bus(sbus)
    );

    api #(
        .ADDR_BITS(RAM_ADDR_BITS)
    ) api (
        .clk(sdram_pll),
        .sdio(sbus),
        .prg(api_prg.device),
        .chr(api_chr.device),
        .write_active(loading)
    );
endmodule
