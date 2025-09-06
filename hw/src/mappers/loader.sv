module loader (
    map_bus.mapper bus,
    input logic [31:0] args
);
    logic [7:0] rom[1024]  /* synthesis syn_romstyle = "EBR" */;
    initial $readmemh("loader/loader.mem", rom);

    logic vblank;
    logic last_ppu_a13;
    logic [1:0] chr_bank;
    logic [7:0] scanline_cnt;
    logic [5:0] tile_cnt;
    logic [1:0] match_ppu;
    logic nbuffer;

    assign bus.cpu_oe = 1;
    assign bus.prg_oe = bus.cpu_rw && bus.cpu_addr[15];
    assign bus.chr_addr = bus.ADDR_BITS'({nbuffer, chr_bank, bus.ppu_addr[11:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = 0;
    assign bus.ciram_a10 = bus.ppu_addr[10];

    always_ff @(posedge bus.m2) begin
        if (bus.cpu_rw) begin
            bus.cpu_data_out <= rom[bus.cpu_addr[9:0]];
        end
    end

    always_ff @(negedge bus.m2) begin
        vblank <= 0;

        // read control register
        if (bus.cpu_addr[15] && !bus.cpu_rw) begin
            if (bus.cpu_data_in[0]) begin
                vblank  <= 1;
                nbuffer <= args[0];
            end
        end
    end

    // detect scanline
    always_ff @(negedge bus.ppu_rd or posedge vblank) begin
        if (vblank) begin
            scanline_cnt <= '0;
            tile_cnt <= '0;
            chr_bank <= '0;
            match_ppu <= '0;
        end else begin
            last_ppu_a13 <= bus.ppu_addr[13];

            if (bus.ppu_addr[13:12] == 2'b10) begin
                if (match_ppu == 3) begin
                    tile_cnt <= '0;
                    scanline_cnt <= scanline_cnt + 1;
                end else match_ppu <= match_ppu + 1;
            end else begin
                match_ppu <= '0;
            end

            if (last_ppu_a13 && !bus.ppu_addr[13]) begin
                tile_cnt <= tile_cnt + 1;
            end

            // switch bank before reading 2 tiles from next scanline
            if (!last_ppu_a13 && bus.ppu_addr[13] && tile_cnt == 40) begin
                if (scanline_cnt == 64) chr_bank <= 1;
                if (scanline_cnt == 128) chr_bank <= 2;
                if (scanline_cnt == 192) chr_bank <= 3;
            end
        end
    end
endmodule
