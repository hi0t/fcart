module launcher (
    map_bus.mapper bus,
    input logic [3:0] ctrl,
    output logic status,
    output logic [9:0] st_rec_addr,
    input logic [7:0] st_rec_read,
    output logic [7:0] st_rec_write
);
    (* syn_romstyle = "block_ram" *) logic [7:0] rom[1024];
    initial $readmemh("launcher/launcher.mem", rom);

    logic vblank;
    logic last_ppu_a13;
    logic [1:0] chr_bank;
    logic [7:0] scanline_cnt;
    logic [5:0] tile_cnt;
    logic [1:0] match_ppu;
    logic sst_hi;
    logic rec_hi;
    logic sst_inc;
    logic rec_inc;

    assign bus.cpu_data_oe = (bus.cpu_addr != 'h5003);
    assign bus.prg_oe = bus.cpu_rw && (bus.cpu_addr[15] || (bus.cpu_addr == 'h5000) || (bus.cpu_addr == 'h5003) || (bus.cpu_addr == 'h5005));
    assign bus.prg_we = !bus.cpu_rw && (bus.cpu_addr == 'h5003);
    assign bus.chr_addr = bus.ADDR_BITS'({ctrl[0], chr_bank, bus.ppu_addr[11:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = 0;
    assign bus.ciram_a10 = bus.ppu_addr[10];

    assign bus.wram_ce = 0;
    assign bus.audio = '0;
    assign bus.irq = 1;
    assign bus.sst_data_out = 'hFF;
    assign st_rec_write = bus.cpu_data_in;

    logic [7:0] rom_q;
    always_ff @(posedge bus.m2) begin
        if (bus.cpu_rw) rom_q <= rom[bus.cpu_addr[9:0]];
    end

    always_comb begin
        if (bus.cpu_addr == 'h5000) begin
            // write control register
            bus.cpu_data_out = {6'b0, ctrl[2:1]};
        end else if (bus.cpu_addr == 'h5005) begin
            // state recorder readout
            bus.cpu_data_out = st_rec_read;
            // Intercept NMI vector to lad in game menu
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
            sst_hi <= 0;
            rec_hi <= 0;
        end else begin
            vblank <= 0;

            if (!bus.cpu_rw) begin
                // read status register
                if (bus.cpu_addr == 'h5001) begin
                    {status, vblank} <= bus.cpu_data_in[1:0];
                end else if (bus.cpu_addr == 'h5002) begin
                    if (sst_hi) bus.prg_addr[14:8] <= bus.cpu_data_in[6:0];
                    else bus.prg_addr[7:0] <= bus.cpu_data_in;
                    sst_hi  <= !sst_hi;
                    sst_inc <= 0;
                end else if (bus.cpu_addr == 'h5004) begin
                    if (rec_hi) st_rec_addr[9:8] <= bus.cpu_data_in[1:0];
                    else st_rec_addr[7:0] <= bus.cpu_data_in;
                    rec_hi  <= !rec_hi;
                    rec_inc <= 0;
                end
            end else if (ctrl[3] && bus.cpu_addr == 'hFFFA) begin
                sst_hi <= 0;
                rec_hi <= 0;
                bus.prg_addr <= '0;
                st_rec_addr <= '0;
                sst_inc <= 0;
                rec_inc <= 0;
            end

            if (sst_inc) begin
                bus.prg_addr <= bus.prg_addr + 1;
                sst_inc <= 0;
            end

            if (rec_inc) begin
                st_rec_addr <= st_rec_addr + 1;
                rec_inc <= 0;
            end

            if (bus.cpu_addr == 'h5003) begin
                sst_inc <= 1;  // Schedule delayed increment to ensure address hold time
            end

            if (bus.cpu_addr == 'h5005) begin
                rec_inc <= 1;  // Schedule delayed increment to ensure address hold time
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
                // Check multiple of 64 (0, 64, 128, 192)
                // 64  = 8'b01000000 -> Bank 1
                // 128 = 8'b10000000 -> Bank 2
                // 192 = 8'b11000000 -> Bank 3
                if (scanline_cnt[5:0] == 0) chr_bank <= scanline_cnt[7:6];
            end
        end
    end

    always_ff @(negedge bus.ppu_rd) begin
        last_ppu_a13 <= bus.ppu_addr[13];
    end
endmodule
