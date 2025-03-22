module fcart (
    input logic CLK,

    // QSPI
    input logic QSPI_CLK,
    input logic QSPI_NCS,
    inout wire [3:0] QSPI_IO,

    // SDRAM
    output logic SDRAM_CLK,
    output logic SDRAM_CS,
    output logic [11:0] SDRAM_ADDR,
    output logic [1:0] SDRAM_BA,
    inout wire [15:0] SDRAM_DQ,
    output logic SDRAM_RAS,
    output logic SDRAM_CAS,
    output logic SDRAM_WE,
    output logic [1:0] SDRAM_DQM,

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
    output logic CPU_DIR,
    output logic PPU_DIR
);

    assign IRQ = 1;

    logic pll_locked;
    logic refresh;

    pll pll (
        .CLKI (CLK),
        .CLKOP(SDRAM_CLK),
        .LOCK (pll_locked)
    );

    sdram_bus sdram_ch0 (), sdram_ch1 ();
    sdram sdram (
        .init(pll_locked),
        .ch0(sdram_ch0.slave),
        .ch1(sdram_ch1.slave),
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

    qspi_bus qspi_bus ();
    qspi qspi (
        .qspi_clk(QSPI_CLK),
        .qspi_ncs(QSPI_NCS),
        .qspi_io(QSPI_IO),
        .bus(qspi_bus.slave)
    );

    api api (
        .clk  (QSPI_CLK),
        .sdram(sdram_ch0.master),
        .qspi (qspi_bus.master)
    );

endmodule
