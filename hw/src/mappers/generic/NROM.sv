module NROM (
    map_bus.mapper bus
);
    // CPU
    assign bus.prg_addr = bus.ADDR_BITS'({bus.cpu_addr[14:0]});
    assign bus.prg_oe = bus.cpu_rw && bus.cpu_addr[15];
    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({bus.ppu_addr[12:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;
    assign bus.ciram_a10 = bus.mirroring ? bus.ppu_addr[10] : bus.ppu_addr[11];

    assign bus.cpu_data_oe = 0;
    assign bus.wram_ce = 0;
    assign bus.prg_we = 0;
    assign bus.audio = '0;
    assign bus.irq = 1;
    assign bus.sst_data_out = 'hFF;
endmodule
