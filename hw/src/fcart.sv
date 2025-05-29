module fcart (
    input logic CLK_IN,

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
    output logic SND_SYN,
    output logic CPU_DIR,
    output logic PPU_DIR
);
    assign IRQ = 1'b1;
    assign SND_SYN = 1'b0;

    logic clk;
    logic async_nreset;
    logic reset;
    logic cpu_read;
    logic ppu_read;
    logic [7:0] cpu_data, ppu_data;
    logic refresh;
    logic loading;
    sdram_bus ch_ppu (), ch_cpu (), ch_api ();

    initial loading = 1;

    assign cpu_read  = !ROMSEL && CPU_RW;
    assign ppu_read  = CIRAM_CE && !PPU_RD;
    assign CPU_DATA  = cpu_read ? cpu_data : 'z;
    assign PPU_DATA  = ppu_read ? ppu_data : 'z;
    assign CPU_DIR   = cpu_read;
    assign PPU_DIR   = ppu_read;
    assign CIRAM_CE  = !PPU_ADDR[13];
    assign CIRAM_A10 = PPU_ADDR[10];

    prg_rom prg_rom (
        .clk(clk),
        .en(!loading),
        .ram(ch_cpu.controller),
        .refresh(refresh),
        .m2(M2),
        .oe(!ROMSEL),
        .addr(CPU_ADDR),
        .data(cpu_data)
    );

    chr_rom chr_rom (
        .clk (clk),
        .en  (!loading),
        .ram (ch_ppu.controller),
        .ce  (CIRAM_CE),
        .oe  (!PPU_RD),
        .addr(PPU_ADDR[12:0]),
        .data(ppu_data)
    );

    pll pll (
        .CLKI (CLK_IN),
        .CLKOP(clk),
        .CLKOS(SDRAM_CLK),
        .LOCK (async_nreset)
    );
    logic [1:0] rst_sync = '0;
    always_ff @(posedge clk) begin
        rst_sync <= {rst_sync[0], async_nreset};
        reset <= !rst_sync[1];
    end

    sdram sdram (
        .clk(clk),
        .reset(reset),
        .ch0(ch_cpu.memory),
        .ch1(ch_ppu.memory),
        .ch2(ch_api.memory),
        .refresh(refresh),
        .sdram_cs(SDRAM_CS),
        .sdram_addr(SDRAM_ADDR),
        .sdram_ba(SDRAM_BA),
        .sdram_dq(SDRAM_DQ),
        .sdram_ras(SDRAM_RAS),
        .sdram_cas(SDRAM_CAS),
        .sdram_we(SDRAM_WE),
        .sdram_dqm(SDRAM_DQM)
    );

    bidir_bus bidir_bus ();
    qspi qspi (
        .clk(clk),
        .async_reset(!async_nreset),
        .bus(bidir_bus.provider),
        .qspi_clk(QSPI_CLK),
        .qspi_ncs(QSPI_NCS),
        .qspi_io(QSPI_IO)
    );

    api api (
        .clk(clk),
        .reset(reset),
        .loading(loading),
        .ram(ch_api.controller),
        .bus(bidir_bus.consumer)
    );
endmodule
