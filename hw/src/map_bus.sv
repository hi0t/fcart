interface map_bus #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
);
    logic reset;

    // Cart interface
    logic m2;
    logic [15:0] cpu_addr;
    logic [7:0] cpu_data_in;
    logic [7:0] cpu_data_out;
    logic custom_cpu_out;
    logic cpu_rw;
    logic irq;
    logic ppu_rd;
    logic ppu_wr;
    logic ciram_a10;
    logic ciram_ce;
    logic [13:0] ppu_addr;

    // Ram interface
    logic [ADDR_BITS-1:0] prg_addr;
    logic prg_oe;
    logic prg_we;
    logic wram_ce;  // Enable working RAM chip on prg line
    logic [ADDR_BITS-1:0] chr_addr;
    logic chr_ce;
    logic chr_oe;
    logic chr_we;

    // Config
    logic chr_ram;
    logic mirroring;

    // Audio
    logic [15:0] audio;

    modport mapper(
        input reset, m2, cpu_addr, cpu_data_in, cpu_rw, ppu_rd, ppu_wr, ppu_addr, chr_ram, mirroring,
        output custom_cpu_out, cpu_data_out, irq, ciram_a10, ciram_ce, prg_addr, prg_oe, prg_we, wram_ce, chr_addr, chr_ce, chr_oe, chr_we, audio
    );
endinterface
