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
    assign bus.chr_we = bus.args[6] ? !bus.ppu_wr : 0;
    assign bus.ciram_a10 = bus.args[5] ? bus.ppu_addr[10] : bus.ppu_addr[11];
endmodule
