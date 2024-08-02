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
    localparam RAM_ADDR_BITS = 25;

    logic [RAM_ADDR_BITS-1:0] prg_offset;
    logic [RAM_ADDR_BITS-1:0] chr_offset;
    logic cpu_read;
    logic ppu_read;
    logic load_state;
    logic [1:0] load_state_buffered;
    logic sdram_pll;
    logic pll_locked;

    sdram_bus #(RAM_ADDR_BITS - 1, 16) ram_api (sdram_pll);
    sdram_bus #(RAM_ADDR_BITS, 8) ram_prg (sdram_pll);
    sdram_bus #(RAM_ADDR_BITS, 8) ram_chr (sdram_pll);

    assign cpu_read = !load_state_buffered[1] && !ROM_CE && CPU_RW;
    assign ppu_read = !load_state_buffered[1] && !PPU_ADDR[13] && !PPU_RD;
    assign CPU_DATA = cpu_read ? ram_prg.data_read : 'z;
    assign PPU_DATA = ppu_read ? ram_chr.data_read : 'z;
    assign CPU_DIR = cpu_read;
    assign PPU_DIR = ppu_read;
    assign CIRAM_CE = !PPU_ADDR[13];
    assign CIRAM_A10 = PPU_ADDR[10];
    assign ram_prg.read = cpu_read;
    assign ram_prg.write = 0;
    assign ram_prg.address = {10'b0, CPU_ADDR} | prg_offset;
    assign ram_prg.data_write = 'x;
    assign ram_prg.refresh = 0;
    assign ram_chr.read = ppu_read;
    assign ram_chr.write = 0;
    assign ram_chr.address = {12'b0, PPU_ADDR[12:0]} | chr_offset;
    assign ram_chr.data_write = 'x;
    assign ram_chr.refresh = ppu_read;

    always_ff @(posedge M2) load_state_buffered <= {load_state_buffered[0], load_state};

    pll pll (
        .inclk0(CLK),
        .c0(sdram_pll),
        .locked(pll_locked)
    );

    sdram #(
        .ADDR_BITS(13),
        .COLUMN_BITS(9),
        .REFRESH_INTERVAL(975)
    ) ram (
        .clk(sdram_pll),
        .ch_16bit(ram_api),
        .ch0_8bit(ram_prg),
        .ch1_8bit(ram_chr),
        .init(pll_locked),
        .cke(SDRAM_CKE),
        .cs(SDRAM_CS),
        .address(SDRAM_ADDR),
        .bank(SDRAM_BA),
        .dq(SDRAM_DQ),
        .ras(SDRAM_RAS),
        .cas(SDRAM_CAS),
        .we(SDRAM_WE),
        .dqm(SDRAM_DQM)
    );

    // TODO connect SDRAM_CLK directly to PLL pin
    altddio_out #(
        .extend_oe_disable("OFF"),
        .intended_device_family("Cyclone V"),
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
        .ram (ram_api),
        .sdio(sbus),

        .prg_offset(prg_offset),
        .chr_offset(chr_offset),
        .load_state(load_state)
    );
endmodule
