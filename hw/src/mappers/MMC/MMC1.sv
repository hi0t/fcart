module MMC1 (
    map_bus.mapper bus
);
    (* syn_state_machine=0 *)logic [4:0] shift;
    logic [4:0] shift_next;
    logic [4:0] control;
    logic [4:0] chr_bank_0;
    logic [4:0] chr_bank_1;
    logic [4:0] prg_bank;
    logic [3:0] prg_sel;
    logic [4:0] chr_sel;

    // CPU
    assign bus.prg_addr = bus.wram_ce ? bus.ADDR_BITS'(bus.cpu_addr[12:0]) : bus.ADDR_BITS'({chr_sel[4], prg_sel, bus.cpu_addr[13:0]});
    assign bus.prg_oe = bus.cpu_rw && (bus.cpu_addr[15] || bus.wram_ce);
    assign bus.prg_we = !bus.cpu_rw && bus.wram_ce;
    assign bus.wram_ce = (bus.cpu_addr[15:13] == 3'b011) && (bus.submapper == 1 || !prg_bank[4]);  // WRAM at $6000-$7FFF

    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({bus.chr_ram ? {4'b0000, bus.ppu_addr[12]} : chr_sel, bus.ppu_addr[11:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_oe = !bus.ppu_rd;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;
    assign shift_next = {bus.cpu_data_in[0], shift[4:1]};

    assign bus.cpu_data_oe = 0;
    assign bus.audio = '0;
    assign bus.irq = 1;

    always_comb begin
        if (bus.submapper == 2) begin
            bus.ciram_a10 = bus.mirroring ? bus.ppu_addr[10] : bus.ppu_addr[11];
        end else begin
            case (control[1:0])
                2'b00: bus.ciram_a10 = 0;
                2'b01: bus.ciram_a10 = 1;
                2'b10: bus.ciram_a10 = bus.ppu_addr[10];
                2'b11: bus.ciram_a10 = bus.ppu_addr[11];
            endcase
        end

        casez ({
            control[3:2], bus.cpu_addr[14]
        })
            3'b0?_?: prg_sel = {prg_bank[3:1], bus.cpu_addr[14]};
            3'b10_0: prg_sel = 4'b0000;
            3'b10_1: prg_sel = prg_bank[3:0];
            3'b11_0: prg_sel = prg_bank[3:0];
            3'b11_1: prg_sel = 4'b1111;
        endcase

        casez ({
            control[4], bus.ppu_addr[12]
        })
            2'b0_?: chr_sel = {chr_bank_0[4:1], bus.ppu_addr[12]};
            2'b1_0: chr_sel = chr_bank_0;
            2'b1_1: chr_sel = chr_bank_1;
        endcase
    end

    always_ff @(negedge bus.m2) begin
        if (bus.reset) begin
            shift <= 5'b10000;
            control <= 5'b01100;
            chr_bank_0 <= '0;
            chr_bank_1 <= '0;
            prg_bank <= '0;
        end else if (bus.sst_enable) begin
            if (bus.sst_we && bus.sst_addr == 'd0) shift <= bus.sst_data_in[4:0];
            if (bus.sst_we && bus.sst_addr == 'd1) control <= bus.sst_data_in[4:0];
            if (bus.sst_we && bus.sst_addr == 'd2) chr_bank_0 <= bus.sst_data_in[4:0];
            if (bus.sst_we && bus.sst_addr == 'd3) chr_bank_1 <= bus.sst_data_in[4:0];
            if (bus.sst_we && bus.sst_addr == 'd4) prg_bank <= bus.sst_data_in[4:0];
        end else if (bus.cpu_addr[15] && !bus.cpu_rw) begin
            if (bus.cpu_data_in[7]) begin
                shift   <= 5'b10000;
                control <= control | 5'b01100;
            end else begin
                if (shift[0]) begin
                    case (bus.cpu_addr[14:13])
                        2'd0: control <= shift_next;
                        2'd1: chr_bank_0 <= shift_next;
                        2'd2: chr_bank_1 <= shift_next;
                        2'd3: prg_bank <= shift_next;
                    endcase
                    shift <= 5'b10000;
                end else shift <= shift_next;
            end
        end
    end

    assign bus.sst_data_out = (bus.sst_addr == 'd0) ? {3'b0, shift} :
                              (bus.sst_addr == 'd1) ? {3'b0, control} :
                              (bus.sst_addr == 'd2) ? {3'b0, chr_bank_0} :
                              (bus.sst_addr == 'd3) ? {3'b0, chr_bank_1} :
                              (bus.sst_addr == 'd4) ? {3'b0, prg_bank} : 'hFF;
endmodule
