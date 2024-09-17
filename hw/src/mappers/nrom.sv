`include "map.svh"

module nrom (
    input  map::in  in,
    output map::out out
);
    assign out.prg_ram.addr = {{map::ADDR_BITS - 15{1'b0}}, in.cpu_addr};
    assign out.prg_ram.oe = !in.rom_ce;
    assign out.prg_ram.we = !in.cpu_rw;

    assign out.chr_ram.addr = {{map::ADDR_BITS - 13{1'b0}}, in.ppu_addr[12:0]};
    assign out.chr_ram.oe = !in.ppu_addr[13] && (!in.ppu_rd || !in.ppu_wr);
    assign out.chr_ram.we = !in.ppu_wr;
    assign out.ciram_a10 = in.ppu_addr[10];
    assign out.ciram_ce = !in.ppu_addr[13];
endmodule
