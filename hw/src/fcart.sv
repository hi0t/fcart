module fcart (
    input logic CLK,

    // QSPI
    input  logic SPI_SCK,
    input  logic SPI_CS,
    input  logic SPI_MOSI,
    output logic SPI_MISO,

    // SDRAM
    output logic SDRAM_CLK,
    output logic SDRAM_CS,
    output logic [11:0] SDRAM_ADDR,
    output logic [1:0] SDRAM_BA,
    inout wire [15:0] SDRAM_DQ,
    output logic SDRAM_RAS,
    output logic SDRAM_CAS,
    output logic SDRAM_WE,
    output logic SDRAM_DQM,

    // Cart
    input logic M2,
    input logic [14:0] CPU_ADDR,
    inout wire [7:0] CPU_DATA,
    input logic CPU_RW,
    input logic ROMSEL,
    output logic IRQ,
    input logic PPU_RD,
    input logic PPU_WR,
    output logic CIRAM_A10,
    output logic CIRAM_CE,
    input logic [13:0] PPU_ADDR,
    inout wire [7:0] PPU_DATA,
    output logic SND_SYN,
    output logic CPU_DIR,
    output logic PPU_DIR
);
    assign IRQ = 1'b1;
    assign SND_SYN = 1'b0;

    logic cpu_read;
    logic ppu_read;
    logic [7:0] cpu_data, ppu_data;
    logic pll_locked;
    logic refresh;
    logic loading;
    sdram_bus ch_ppu (), ch_cpu (), ch_api ();

    initial loading = 0;

    assign cpu_read  = !ROMSEL && CPU_RW && M2;
    assign ppu_read  = CIRAM_CE && !PPU_RD;
    assign CPU_DATA  = cpu_read ? cpu_data : 'z;
    assign PPU_DATA  = ppu_read ? ppu_data : 'z;
    assign CPU_DIR   = cpu_read;
    assign PPU_DIR   = ppu_read;
    assign CIRAM_CE  = !PPU_ADDR[13];
    assign CIRAM_A10 = PPU_ADDR[10];

    prg_rom prg_rom (
        .clk(SDRAM_CLK),
        .en(!loading),
        .ram(ch_cpu.master),
        .refresh(refresh),
        .m2(M2),
        .cpu_rw(CPU_RW),
        .romsel(ROMSEL),
        .addr(CPU_ADDR),
        .data(cpu_data)
    );

    chr_rom chr_rom (
        .clk(SDRAM_CLK),
        .en(!loading),
        .ram(ch_ppu.master),
        .ppu_rd(PPU_RD),
        .ciram_ce(CIRAM_CE),
        .addr(PPU_ADDR[12:0]),
        .data(ppu_data)
    );

    pll pll (
        .inclk0(CLK),
        .c0(SDRAM_CLK),
        .locked(pll_locked)
    );

    sdram sdram (
        .init(pll_locked),
        .ch0(ch_ppu.slave),
        .ch1(ch_cpu.slave),
        .ch2(ch_api.slave),
        .refresh(refresh),
        .sdram_clk(SDRAM_CLK),
        .sdram_cs(SDRAM_CS),
        .sdram_addr(SDRAM_ADDR),
        .sdram_ba(SDRAM_BA),
        .sdram_dq(SDRAM_DQ),
        .sdram_ras(SDRAM_RAS),
        .sdram_cas(SDRAM_CAS),
        .sdram_we(SDRAM_WE),
        .sdram_dqm(SDRAM_DQM)
    );

    wire  [3:0] qspi_io;
    logic [3:0] io_buf;
    assign qspi_io = SPI_CS ? io_buf : 'z;
    qspi_bus qspi_bus ();
    qspi qspi (
        .clk(SPI_SCK),
        .ncs(SPI_CS),
        .io (qspi_io),
        .bus(qspi_bus.slave)
    );

    api api (
        .clk(SPI_SCK),
        .loading(loading),
        .sdram(ch_api.master),
        .qspi(qspi_bus.master)
    );

endmodule
