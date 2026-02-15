module VRC6 (
    map_bus.mapper bus
);
    logic [7:0] prg_bank_8000;
    logic [7:0] prg_bank_C000;
    logic [7:0] chr_bank_sel;
    logic [7:0] chr_bank[8];
    logic [1:0] mirroring;
    logic [1:0] low_addr;
    logic write_en;

    logic [7:0] vrc_sst;
    logic [7:0] snd_sst;

    // CPU
    always_comb begin
        if (bus.cpu_addr[14] == 0) bus.prg_addr = bus.ADDR_BITS'({prg_bank_8000, bus.cpu_addr[13:0]});
        else if (bus.cpu_addr[13] == 0) bus.prg_addr = bus.ADDR_BITS'({prg_bank_C000, bus.cpu_addr[12:0]});
        else bus.prg_addr = bus.ADDR_BITS'({8'hFF, bus.cpu_addr[12:0]});
    end
    assign bus.prg_oe = bus.cpu_rw && bus.cpu_addr[15];

    // PPU
    assign chr_bank_sel = chr_bank[bus.ppu_addr[12:10]];  // 3 bits -> 8 banks
    assign bus.chr_addr = bus.ADDR_BITS'({chr_bank_sel, bus.ppu_addr[9:0]});  // 1KB pages
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;
    assign bus.chr_oe = !bus.ppu_rd;

    assign bus.cpu_data_oe = 0;
    assign bus.wram_ce = 0;
    assign bus.prg_we = 0;

    always_comb begin
        case (mirroring)
            0: bus.ciram_a10 = bus.ppu_addr[10]; // Vert
            1: bus.ciram_a10 = bus.ppu_addr[11]; // Horiz
            2: bus.ciram_a10 = 0;              // 1ScA
            3: bus.ciram_a10 = 1;              // 1ScB
        endcase
    end

    // VRC6a
    assign low_addr = bus.cpu_addr[1:0];
    assign write_en = bus.cpu_addr[15] && !bus.cpu_rw;

    always_ff @(negedge bus.m2) begin
        if (bus.reset) begin
            prg_bank_8000 <= '0;
            prg_bank_C000 <= '0;
            mirroring <= '0;
            chr_bank <= '{default: 0};
        end else if (bus.sst_enable) begin
            if (bus.sst_we && bus.sst_addr[5:3] == 'd0) chr_bank[bus.sst_addr[2:0]] <= bus.sst_data_in;
            if (bus.sst_we && bus.sst_addr == 'd8) prg_bank_8000 <= bus.sst_data_in;
            if (bus.sst_we && bus.sst_addr == 'd9) prg_bank_C000 <= bus.sst_data_in;
            if (bus.sst_we && bus.sst_addr == 'd10) mirroring <= bus.sst_data_in[1:0];
        end else begin
            // Write Logic
            if (write_en) begin
                casez ({
                    bus.cpu_addr[14:12], low_addr
                })
                    5'b000_??: prg_bank_8000 <= bus.cpu_data_in; // $8000
                    5'b011_11: mirroring <= bus.cpu_data_in[3:2]; // $B003
                    5'b100_??: prg_bank_C000 <= bus.cpu_data_in; // $C000
                    5'b101_00: chr_bank[0] <= bus.cpu_data_in; // $D000
                    5'b101_01: chr_bank[1] <= bus.cpu_data_in; // $D001
                    5'b101_10: chr_bank[2] <= bus.cpu_data_in; // $D002
                    5'b101_11: chr_bank[3] <= bus.cpu_data_in; // $D003
                    5'b110_00: chr_bank[4] <= bus.cpu_data_in; // $E000
                    5'b110_01: chr_bank[5] <= bus.cpu_data_in; // $E001
                    5'b110_10: chr_bank[6] <= bus.cpu_data_in; // $E002
                    5'b110_11: chr_bank[7] <= bus.cpu_data_in; // $E003
                    default;
                endcase
            end
        end
    end

    // IRQ Instantiation
    logic [2:0] bank_sel;
    assign bank_sel = bus.cpu_addr[14:12];

    vrc_irq vrc_irq (
        .clk(bus.m2),
        .reset(bus.reset),
        .cpu_data_in(bus.cpu_data_in),
        .wr_latch(write_en && (bank_sel == 3'b111) && (low_addr == 2'b00)),
        .wr_ctrl(write_en && (bank_sel == 3'b111) && (low_addr == 2'b01)),
        .wr_ack(write_en && (bank_sel == 3'b111) && (low_addr == 2'b10)),
        .irq(bus.irq),

        .sst_enable(bus.sst_enable),
        .sst_we(bus.sst_we),
        .sst_addr(bus.sst_addr),
        .sst_data_in(bus.sst_data_in),
        .sst_data_out(vrc_sst)
    );

    vrc6_sound vrc6_sound (
        .clk(bus.m2),
        .reset(bus.reset),
        .cpu_addr({bus.cpu_addr[15:2], low_addr}),
        .cpu_data_in(bus.cpu_data_in),
        .cpu_we(write_en),
        .audio_out(bus.audio),

        .sst_enable(bus.sst_enable),
        .sst_we(bus.sst_we),
        .sst_addr(bus.sst_addr),
        .sst_data_in(bus.sst_data_in),
        .sst_data_out(snd_sst)
    );

    assign bus.sst_data_out = (bus.sst_addr[5:3] == 'd0) ? chr_bank[bus.sst_addr[2:0]] :
                                  (bus.sst_addr == 'd8) ? prg_bank_8000 :
                                  (bus.sst_addr == 'd9) ? prg_bank_C000 :
                                  (bus.sst_addr == 'd10) ? {6'b0, mirroring} :
                                  (bus.sst_addr[5:3] == 'd2) ? vrc_sst :
                                  snd_sst;
endmodule
