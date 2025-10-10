module fcart (
    input  logic CLK_IN,
    output logic FPGA_IRQ,

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
    logic [31:0] wr_reg;
    logic [3:0] wr_reg_addr;
    logic wr_reg_changed;
    logic [31:0] launcher_status;
    sdram_bus #(.ADDR_BITS(RAM_ADDR_BITS)) ch_ppu (), ch_cpu (), ch_api ();

    map_mux mux (
        .clk(clk),
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

        .wr_reg(wr_reg[11:0]),
        .wr_reg_addr(wr_reg_addr),
        .wr_reg_changed(wr_reg_changed),
        .status_reg(launcher_status)
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

    logic [7:0] qspi_rd_data;
    logic qspi_rd_valid;
    logic qspi_rd_ready;
    logic [7:0] qspi_wr_data;
    logic qspi_wr_valid;
    logic qspi_wr_ready;
    logic qspi_start;
    qspi qspi (
        .clk(clk),
        .async_reset(!async_nreset),

        .rd_data(qspi_rd_data),
        .rd_valid(qspi_rd_valid),
        .rd_ready(qspi_rd_ready),
        .wr_data(qspi_wr_data),
        .wr_valid(qspi_wr_valid),
        .wr_ready(qspi_wr_ready),
        .start(qspi_start),

        .qspi_clk(QSPI_CLK),
        .qspi_ncs(QSPI_NCS),
        .qspi_io (QSPI_IO)
    );

    api api (
        .clk(clk),
        .reset(reset),
        .fpga_irq(FPGA_IRQ),

        .wr_reg(wr_reg),
        .wr_reg_addr(wr_reg_addr),
        .wr_reg_changed(wr_reg_changed),
        .ev_reg(launcher_status),

        .ram(ch_api.controller),

        .rd_data(qspi_rd_data),
        .rd_valid(qspi_rd_valid),
        .rd_ready(qspi_rd_ready),
        .wr_data(qspi_wr_data),
        .wr_valid(qspi_wr_valid),
        .wr_ready(qspi_wr_ready),
        .start(qspi_start)
    );
endmodule
