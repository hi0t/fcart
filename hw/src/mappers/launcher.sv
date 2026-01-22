module launcher (
    map_bus.mapper bus,
    input logic [3:0] ctrl,
    output logic status
);
    logic [7:0] rom[1024]  /* synthesis syn_romstyle = "EBR" */;
    initial $readmemh("launcher/launcher.mem", rom);

    logic vblank;
    logic last_ppu_a13;
    logic [1:0] chr_bank;
    logic [7:0] scanline_cnt;
    logic [5:0] tile_cnt;
    logic [1:0] match_ppu;

    assign bus.custom_cpu_out = 1;
    assign bus.prg_oe = bus.cpu_rw && (bus.cpu_addr[15] || (bus.cpu_addr == 'h5000));
    assign bus.chr_addr = bus.ADDR_BITS'({ctrl[0], chr_bank, bus.ppu_addr[11:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = 0;
    assign bus.ciram_a10 = bus.ppu_addr[10];

    assign bus.wram_ce = 0;
    assign bus.prg_we = 0;
    assign bus.audio = '0;

    logic [7:0] rom_q;
    always_ff @(posedge bus.m2) begin
        if (bus.cpu_rw) rom_q <= rom[bus.cpu_addr[9:0]];
    end

    always_comb begin
        if (bus.cpu_addr == 'h5000) begin
            // write control register
            bus.cpu_data_out = {6'b0, ctrl[2:1]};
            // Intercept NMI vector
        end else if (ctrl[3] && bus.cpu_addr == 'hFFFA) begin
            bus.cpu_data_out = 'h00;  // low byte of $FC00
        end else if (ctrl[3] && bus.cpu_addr == 'hFFFB) begin
            bus.cpu_data_out = 'hFC;  // high byte of $FC00
        end else begin
            bus.cpu_data_out = rom_q;
        end
    end

    always_ff @(negedge bus.m2) begin
        if (bus.reset) begin
            status <= 0;
            vblank <= 1;
        end else begin
            vblank <= 0;

            if (!bus.cpu_rw) begin
                // read status register
                if (bus.cpu_addr == 'h5002) begin
                    if (bus.cpu_data_in[0]) vblank <= 1;
                    status <= bus.cpu_data_in[1];
                end
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

    always_ff @(negedge bus.ppu_rd) begin
        last_ppu_a13 <= bus.ppu_addr[13];
    end
endmodule
