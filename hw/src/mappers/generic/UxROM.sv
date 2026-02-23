module UxROM (
    map_bus.mapper bus
);
    logic [4:0] prg_bank;
    logic [4:0] bank;

    always_comb begin
        if (bus.submapper == 2) begin
            bank = bus.cpu_addr[14] ? prg_bank : 5'b00000;
        end else if (bus.submapper == 1) begin
            bank = bus.cpu_addr[14] ? 5'b11111 : {2'b0, prg_bank[4:2]};
        end else begin
            bank = bus.cpu_addr[14] ? 5'b11111 : prg_bank;
        end
    end

    // CPU
    assign bus.prg_addr = bus.ADDR_BITS'({bank, bus.cpu_addr[13:0]});
    assign bus.prg_oe = bus.cpu_addr[15] && bus.cpu_rw;
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

    always_ff @(negedge bus.m2) begin
        if (bus.sst_enable) begin
            if (bus.sst_we && bus.sst_addr == 'd0) prg_bank <= bus.sst_data_in[4:0];
        end else if (bus.cpu_addr[15] && !bus.cpu_rw) begin
            prg_bank <= bus.cpu_data_in[4:0];
        end
    end

    assign bus.sst_data_out = (bus.sst_addr == 'd0) ? {3'b0, prg_bank} : 'hFF;
endmodule
