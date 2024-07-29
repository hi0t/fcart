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
    logic [7:0] cpu_tx;
    logic [7:0] ppu_tx;
    logic cpu_read;
    logic ppu_read;
    logic load_state;
    logic [1:0] load_state_buffered;

    sdram_bus #(RAM_ADDR_BITS - 1, 16) ram_api ();
    sdram_bus #(RAM_ADDR_BITS, 8) ram_prg ();
    sdram_bus #(RAM_ADDR_BITS, 8) ram_chr ();

    assign cpu_read = !load_state_buffered[1] && !ROM_CE && CPU_RW;
    assign ppu_read = !load_state_buffered[1] && !PPU_ADDR[13] && !PPU_RD;
    assign CPU_DATA = cpu_read ? cpu_tx : 'z;
    assign PPU_DATA = ppu_read ? ppu_tx : 'z;
    assign CPU_DIR = cpu_read;
    assign PPU_DIR = ppu_read;
    assign CIRAM_CE = !PPU_ADDR[13];
    assign CIRAM_A10 = PPU_ADDR[10];
    assign ram_prg.read = cpu_read;
    assign ram_prg.write = 0;
    assign ram_prg.address = {10'b0, CPU_ADDR} | prg_offset;
    assign cpu_tx = ram_prg.data_read;
    assign ram_prg.data_write = 'x;
    assign ram_chr.read = ppu_read;
    assign ram_chr.write = 0;
    assign ram_chr.address = {12'b0, PPU_ADDR[12:0]} | chr_offset;
    assign ppu_tx = ram_chr.data_read;
    assign ram_chr.data_write = 'x;

    always_ff @(posedge M2) load_state_buffered <= {load_state_buffered[0], load_state};

    pll pll (
        .inclk0(CLK),
        .c0(SDRAM_CLK)
    );

    sdio_bus sbus (.clk(SDIO_CLK));
    sdio sdio (
        .cmd_sdio(SDIO_CMD),
        .bus(sbus)
    );

    sdram #(
        .CLK_FREQ(100_000_000),
        .ADDR_BITS(13),
        .COLUMN_BITS(9),
        .REFRESH_INTERVAL_US(7.81)
    ) ram (
        .clk(SDRAM_CLK),
        .ch_16bit(ram_api),
        .ch0_8bit(ram_chr),  // chr has priority because PPU has a smaller window for reading
        .ch1_8bit(ram_prg),
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
