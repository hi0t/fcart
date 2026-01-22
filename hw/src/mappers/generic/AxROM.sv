module AxROM (
    map_bus.mapper bus
);
    logic [3:0] prg_bank;
    logic nametable_page;

    // CPU
    assign bus.prg_addr = bus.ADDR_BITS'({prg_bank, bus.cpu_addr[14:0]});
    assign bus.prg_oe = bus.cpu_addr[15] && bus.cpu_rw;

    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({bus.ppu_addr[12:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;
    assign bus.ciram_a10 = nametable_page;

    assign bus.custom_cpu_out = 0;
    assign bus.wram_ce = 0;
    assign bus.prg_we = 0;
    assign bus.audio = '0;

    always_ff @(negedge bus.m2) begin
        if (bus.cpu_addr[15] && !bus.cpu_rw) begin
            prg_bank <= bus.cpu_data_in[3:0];
            nametable_page <= bus.cpu_data_in[4];
        end
    end
endmodule
