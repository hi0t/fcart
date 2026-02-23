module MMC3 (
    map_bus.mapper bus
);
    logic [2:0] bank_sel;
    logic prg_mode;
    logic chr_mode;

    logic [7:0] chr_bank[6];
    logic [5:0] prg_bank_0;
    logic [5:0] prg_bank_1;

    logic mirroring;
    logic prg_ram_en;
    logic prg_ram_wp;

    logic [7:0] irq_latch;
    logic [7:0] irq_counter;
    logic irq_reload;
    logic irq_enable;
    logic irq_pending;

    logic [5:0] prg_sel;
    logic [7:0] chr_sel;

    // CPU
    assign bus.prg_addr = bus.wram_ce ? bus.ADDR_BITS'(bus.cpu_addr[12:0]) : bus.ADDR_BITS'({prg_sel, bus.cpu_addr[12:0]});
    assign bus.prg_oe = bus.cpu_rw && (bus.cpu_addr[15] || bus.wram_ce);
    assign bus.prg_we = !bus.cpu_rw && bus.wram_ce && !prg_ram_wp;
    assign bus.wram_ce = (bus.cpu_addr[15:13] == 3'b011) && prg_ram_en;  // WRAM at $6000-$7FFF

    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({chr_sel, bus.ppu_addr[9:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;

    assign bus.cpu_data_oe = 0;
    assign bus.audio = '0;
    assign bus.irq = !irq_pending;

    always_comb begin
        bus.ciram_a10 = mirroring ? bus.ppu_addr[11] : bus.ppu_addr[10];

        case (bus.cpu_addr[14:13])
            2'b00: prg_sel = prg_mode ? 6'h3E : prg_bank_0; // $8000-$9FFF
            2'b01: prg_sel = prg_bank_1;                    // $A000-$BFFF
            2'b10: prg_sel = prg_mode ? prg_bank_0 : 6'h3E; // $C000-$DFFF
            2'b11: prg_sel = 6'h3F;                         // $E000-$FFFF
        endcase

        if (chr_mode) begin
            case (bus.ppu_addr[12:10])
                3'b000: chr_sel = chr_bank[2];
                3'b001: chr_sel = chr_bank[3];
                3'b010: chr_sel = chr_bank[4];
                3'b011: chr_sel = chr_bank[5];
                3'b100: chr_sel = {chr_bank[0][7:1], bus.ppu_addr[10]};
                3'b101: chr_sel = {chr_bank[0][7:1], bus.ppu_addr[10]};
                3'b110: chr_sel = {chr_bank[1][7:1], bus.ppu_addr[10]};
                3'b111: chr_sel = {chr_bank[1][7:1], bus.ppu_addr[10]};
            endcase
        end else begin
            case (bus.ppu_addr[12:10])
                3'b000: chr_sel = {chr_bank[0][7:1], bus.ppu_addr[10]};
                3'b001: chr_sel = {chr_bank[0][7:1], bus.ppu_addr[10]};
                3'b010: chr_sel = {chr_bank[1][7:1], bus.ppu_addr[10]};
                3'b011: chr_sel = {chr_bank[1][7:1], bus.ppu_addr[10]};
                3'b100: chr_sel = chr_bank[2];
                3'b101: chr_sel = chr_bank[3];
                3'b110: chr_sel = chr_bank[4];
                3'b111: chr_sel = chr_bank[5];
            endcase
        end
    end

    logic [2:0] a12_filter;
    logic a12_state;

    always_ff @(negedge bus.m2) begin
        if (bus.reset) begin
            bank_sel <= '0;
            prg_mode <= '0;
            chr_mode <= '0;
            chr_bank <= '{default: 0};
            prg_bank_0 <= '0;
            prg_bank_1 <= '0;
            mirroring <= '0;
            prg_ram_en <= '0;
            prg_ram_wp <= '0;
            irq_latch <= '0;
            irq_reload <= '0;
            irq_enable <= '0;
            irq_pending <= '0;
            irq_counter <= '0;
            a12_filter <= '0;
            a12_state <= '0;
        end else if (bus.sst_enable) begin
            if (bus.sst_we) begin
                case (bus.sst_addr)
                    'd0: {chr_mode, prg_mode, bank_sel} <= {bus.sst_data_in[7:6], bus.sst_data_in[2:0]};
                    'd1: chr_bank[0] <= bus.sst_data_in;
                    'd2: chr_bank[1] <= bus.sst_data_in;
                    'd3: chr_bank[2] <= bus.sst_data_in;
                    'd4: chr_bank[3] <= bus.sst_data_in;
                    'd5: chr_bank[4] <= bus.sst_data_in;
                    'd6: chr_bank[5] <= bus.sst_data_in;
                    'd7: prg_bank_0 <= bus.sst_data_in[5:0];
                    'd8: prg_bank_1 <= bus.sst_data_in[5:0];
                    'd9: {prg_ram_en, prg_ram_wp, mirroring} <= {bus.sst_data_in[7:6], bus.sst_data_in[0]};
                    'd10: irq_latch <= bus.sst_data_in;
                    'd11: irq_counter <= bus.sst_data_in;
                    'd12: {irq_enable, irq_pending, irq_reload} <= bus.sst_data_in[2:0];
                    'd13: a12_state <= bus.sst_data_in[0];
                endcase
            end
        end else begin
            if (bus.cpu_addr[15] && !bus.cpu_rw) begin
                case ({
                    bus.cpu_addr[14:13], bus.cpu_addr[0]
                })
                    3'b00_0: begin  // $8000
                        bank_sel <= bus.cpu_data_in[2:0];
                        prg_mode <= bus.cpu_data_in[6];
                        chr_mode <= bus.cpu_data_in[7];
                    end
                    3'b00_1: begin  // $8001
                        if (!bank_sel[2] || !bank_sel[1]) begin
                            chr_bank[bank_sel] <= bus.cpu_data_in;
                        end else if (!bank_sel[0]) begin
                            prg_bank_0 <= bus.cpu_data_in[5:0];
                        end else begin
                            prg_bank_1 <= bus.cpu_data_in[5:0];
                        end
                    end
                    3'b01_0: mirroring <= bus.cpu_data_in[0]; // $A000
                    3'b01_1: begin // $A001
                        prg_ram_en <= bus.cpu_data_in[7];
                        prg_ram_wp <= bus.cpu_data_in[6];
                    end
                    3'b10_0: irq_latch <= bus.cpu_data_in; // $C000
                    3'b10_1: irq_reload <= 1; // $C001
                    3'b11_0: begin // $E000
                        irq_enable <= 0;
                        irq_pending <= 0;
                    end
                    3'b11_1: irq_enable <= 1; // $E001
                endcase
            end

            a12_filter <= {a12_filter[1:0], bus.ppu_addr[12]};

            if (a12_filter == 3'b000) begin
                a12_state <= 0;
            end else if (bus.ppu_addr[12] == 1 && a12_state == 0) begin
                a12_state <= 1;

                if (irq_counter == 0 || irq_reload) begin
                    irq_counter <= irq_latch;
                    irq_reload  <= 0;
                    if (irq_latch == 0 && irq_enable) irq_pending <= 1;
                end else begin
                    irq_counter <= irq_counter - 1;
                    if (irq_counter == 1 && irq_enable) irq_pending <= 1;
                end
            end
        end
    end

    assign bus.sst_data_out =
        (bus.sst_addr == 'd0) ? {chr_mode, prg_mode, 3'b0, bank_sel} :
        (bus.sst_addr[3:0] != 0 && !bus.sst_addr[3] && (!bus.sst_addr[2] || !bus.sst_addr[1])) ? chr_bank[bus.sst_addr[2:0] - 1] :
        (bus.sst_addr == 'd7) ? {2'b0, prg_bank_0} :
        (bus.sst_addr == 'd8) ? {2'b0, prg_bank_1} :
        (bus.sst_addr == 'd9) ? {prg_ram_en, prg_ram_wp, 5'b0, mirroring} :
        (bus.sst_addr == 'd10) ? irq_latch :
        (bus.sst_addr == 'd11) ? irq_counter :
        (bus.sst_addr == 'd12) ? {5'b0, irq_enable, irq_pending, irq_reload} :
        (bus.sst_addr == 'd13) ? {7'b0, a12_state} : 'hFF;

endmodule
