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
    assign SND_SYN = 1'b0;

    localparam RAM_ADDR_BITS = 22;  // SDRAM row + col + bank bits

    logic clk;
    logic async_nreset;
    logic reset;
    logic [23:0] map_ctrl;
    logic map_ctrl_req;
    logic map_ctrl_ack;
    sdram_bus #(.ADDR_BITS(RAM_ADDR_BITS)) ch_ppu (), ch_cpu (), ch_api ();

    map_mux mux (
        .clk(clk),
        .async_reset(!async_nreset),
        .ch_prg(ch_cpu.controller),
        .ch_chr(ch_ppu.controller),

        .m2(M2),
        .cpu_addr({!ROMSEL, CPU_ADDR}),
        .cpu_data(CPU_DATA),
        .cpu_rw(CPU_RW),
        .irq(IRQ),
        .ppu_rd(PPU_RD),
        .ppu_wr(PPU_WR),
        .ciram_a10(CIRAM_A10),
        .ciram_ce(CIRAM_CE),
        .ppu_addr(PPU_ADDR),
        .ppu_data(PPU_DATA),

        .cpu_oe(CPU_DIR),
        .ppu_oe(PPU_DIR),

        .map_ctrl(map_ctrl),
        .map_ctrl_req(map_ctrl_req),
        .map_ctrl_ack(map_ctrl_ack)
    );

    pll pll (
        .CLKI (CLK_IN),
        .CLKOP(clk),
        .CLKOS(SDRAM_CLK),
        .LOCK (async_nreset)
    );
    logic [1:0] rst_sync;
    assign reset = !rst_sync[1];
    always_ff @(posedge clk) begin
        if (!async_nreset) begin
            rst_sync <= 2'b00;
        end else begin
            rst_sync <= {rst_sync[0], 1'b1};
        end
    end

    logic [2:0] refresh_sync;
    always_ff @(posedge clk)
        // Refresh is performed after the OE cycle is completed.
        refresh_sync <= {
            refresh_sync[1:0], !M2
        };

    sdram sdram (
        .clk(clk),
        .reset(reset),
        .ch0(ch_cpu.memory),
        .ch1(ch_ppu.memory),
        .ch2(ch_api.memory),
        .refresh(!refresh_sync[2] && refresh_sync[1]),
        .sdram_cs(SDRAM_CS),
        .sdram_addr(SDRAM_ADDR),
        .sdram_ba(SDRAM_BA),
        .sdram_dq(SDRAM_DQ),
        .sdram_ras(SDRAM_RAS),
        .sdram_cas(SDRAM_CAS),
        .sdram_we(SDRAM_WE),
        .sdram_dqm(SDRAM_DQM)
    );

    bidir_bus qspi_bus ();
    qspi qspi (
        .clk(clk),
        .async_reset(!async_nreset),
        .bus(qspi_bus.provider),
        .qspi_clk(QSPI_CLK),
        .qspi_ncs(QSPI_NCS),
        .qspi_io(QSPI_IO)
    );

    api api (
        .clk(clk),
        .reset(reset),
        .map_ctrl(map_ctrl),
        .map_ctrl_req(map_ctrl_req),
        .map_ctrl_ack(map_ctrl_ack),
        .ram(ch_api.controller),
        .qspi_bus(qspi_bus.consumer)
    );
endmodule
