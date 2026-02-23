module CNROM (
    map_bus.mapper bus
);
    logic [3:0] chr_bank;
    logic ce;

    always_comb begin
        if (bus.submapper == 1) begin
            ce = bus.ciram_ce && (chr_bank[1:0] == 2'b11);
        end else begin
            ce = bus.ciram_ce;
        end
    end

    // CPU
    assign bus.prg_addr = bus.ADDR_BITS'(bus.cpu_addr[14:0]);
    assign bus.prg_oe = bus.cpu_addr[15] && bus.cpu_rw;
    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({chr_bank, bus.ppu_addr[12:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;
    assign bus.ciram_a10 = bus.mirroring ? bus.ppu_addr[10] : bus.ppu_addr[11];

    assign bus.cpu_data_oe = 0;
    assign bus.wram_ce = 0;
    assign bus.prg_we = 0;
    assign bus.audio = '0;
    assign bus.irq = 1;

    always_ff @(negedge bus.m2) begin
        if (bus.sst_enable) begin
            if (bus.sst_we && bus.sst_addr == 'd0) chr_bank <= bus.sst_data_in[3:0];
        end else if (bus.cpu_addr[15] && !bus.cpu_rw) begin
            chr_bank <= bus.cpu_data_in[3:0];
        end
    end

    assign bus.sst_data_out = (bus.sst_addr == 0) ? {4'b0, chr_bank} : 'hFF;
endmodule
