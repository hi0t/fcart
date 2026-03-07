module FME7 (
    map_bus.mapper bus
);
    logic [3:0] command;
    logic [7:0] chr_bank[8];
    logic [4:0] prg_bank[4];  // 6000, 8000, A000, C000
    logic [1:0] mirroring;
    logic irq_enabled;
    logic irq_counter_enable;
    logic irq_carry;
    logic irq_pending;
    logic [15:0] irq_counter;
    logic wram_select;

    logic [4:0] selected_prg_bank;
    logic [7:0] snd_sst;
    logic write_en;

    // CPU
    assign bus.prg_addr = bus.ADDR_BITS'({selected_prg_bank, bus.cpu_addr[12:0]});
    assign bus.prg_oe   = bus.cpu_rw && (bus.cpu_addr[15] || bus.cpu_addr[15:13] == 3'b011);
    assign bus.prg_we   = !bus.cpu_rw && bus.wram_ce;
    assign bus.wram_ce  = wram_select && bus.cpu_addr[15:13] == 3'b011;

    always_comb begin
        case (bus.cpu_addr[15:13])
            3'b011: selected_prg_bank = prg_bank[0];
            3'b100: selected_prg_bank = prg_bank[1];
            3'b101: selected_prg_bank = prg_bank[2];
            3'b110: selected_prg_bank = prg_bank[3];
            3'b111: selected_prg_bank = 5'b11111;
            default: selected_prg_bank = '0;
        endcase
    end

    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({chr_bank[bus.ppu_addr[12:10]], bus.ppu_addr[9:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce   = bus.ciram_ce;
    assign bus.chr_we   = bus.chr_ram ? !bus.ppu_wr : 0;
    assign bus.chr_oe   = !bus.ppu_rd;

    always_comb begin
        case (mirroring)
            0: bus.ciram_a10 = bus.ppu_addr[10]; // V
            1: bus.ciram_a10 = bus.ppu_addr[11]; // H
            2: bus.ciram_a10 = 0;                // 1ScA
            3: bus.ciram_a10 = 1;                // 1ScB
        endcase
    end

    assign bus.cpu_data_oe = 0;
    assign bus.irq = !(irq_pending && irq_enabled);
    assign write_en = bus.cpu_addr[15] && !bus.cpu_rw;

    always_ff @(negedge bus.m2) begin
        if (bus.reset) begin
            command <= '0;
            prg_bank <= '{default: 0};
            chr_bank <= '{default: 0};
            mirroring <= 0;
            irq_enabled <= 0;
            irq_counter_enable <= 0;
            irq_counter <= 0;
            irq_pending <= 0;
            irq_carry <= 0;
            wram_select <= 0;
        end else if (bus.sst_enable) begin
            if (bus.sst_we) begin
                case (bus.sst_addr)
                    0: command <= bus.sst_data_in[3:0];
                    1: prg_bank[0] <= bus.sst_data_in[4:0];
                    2: prg_bank[1] <= bus.sst_data_in[4:0];
                    3: prg_bank[2] <= bus.sst_data_in[4:0];
                    4: prg_bank[3] <= bus.sst_data_in[4:0];
                    5: chr_bank[0] <= bus.sst_data_in;
                    6: chr_bank[1] <= bus.sst_data_in;
                    7: chr_bank[2] <= bus.sst_data_in;
                    8: chr_bank[3] <= bus.sst_data_in;
                    9: chr_bank[4] <= bus.sst_data_in;
                    10: chr_bank[5] <= bus.sst_data_in;
                    11: chr_bank[6] <= bus.sst_data_in;
                    12: chr_bank[7] <= bus.sst_data_in;
                    13: {wram_select, mirroring, irq_enabled, irq_counter_enable, irq_carry, irq_pending} <= bus.sst_data_in[6:0];
                    14: irq_counter[7:0] <= bus.sst_data_in;
                    15: irq_counter[15:8] <= bus.sst_data_in;
                endcase
            end
        end else begin
            if (irq_counter_enable) begin
                {irq_carry, irq_counter} <= {1'b0, irq_counter} - 1'b1;
                if (irq_carry) irq_pending <= 1;
            end

            if (write_en) begin
                if (bus.cpu_addr[14:13] == 2'b00) begin
                    command <= bus.cpu_data_in[3:0];
                end else if (bus.cpu_addr[14:13] == 2'b01) begin
                    case (command)
                        0: chr_bank[0] <= bus.cpu_data_in;
                        1: chr_bank[1] <= bus.cpu_data_in;
                        2: chr_bank[2] <= bus.cpu_data_in;
                        3: chr_bank[3] <= bus.cpu_data_in;
                        4: chr_bank[4] <= bus.cpu_data_in;
                        5: chr_bank[5] <= bus.cpu_data_in;
                        6: chr_bank[6] <= bus.cpu_data_in;
                        7: chr_bank[7] <= bus.cpu_data_in;
                        8: {wram_select, prg_bank[0]} <= {bus.cpu_data_in[6], bus.cpu_data_in[4:0]};
                        9: prg_bank[1] <= bus.cpu_data_in[4:0];
                        10: prg_bank[2] <= bus.cpu_data_in[4:0];
                        11: prg_bank[3] <= bus.cpu_data_in[4:0];
                        12: mirroring <= bus.cpu_data_in[1:0];
                        13: {irq_counter_enable, irq_enabled, irq_pending} <= {bus.cpu_data_in[7], bus.cpu_data_in[0], 1'b0};
                        14: irq_counter[7:0] <= bus.cpu_data_in;
                        15: irq_counter[15:8] <= bus.cpu_data_in;
                    endcase
                end
            end
        end
    end

    ym2149 psg (
        .clk(bus.m2),
        .reset(bus.reset),
        .cpu_addr(bus.cpu_addr[14:13]),
        .cpu_data_in(bus.cpu_data_in),
        .cpu_we(write_en),
        .audio_out(bus.audio),
        .sst_enable(bus.sst_enable),
        .sst_we(bus.sst_we),
        .sst_addr(bus.sst_addr),
        .sst_data_in(bus.sst_data_in),
        .sst_data_out(snd_sst)
    );

    // Save State Output
    assign bus.sst_data_out = (bus.sst_addr == 0) ? {4'b0, command} :
                              (bus.sst_addr == 1) ? {3'b0, prg_bank[0]} :
                              (bus.sst_addr == 2) ? {3'b0, prg_bank[1]} :
                              (bus.sst_addr == 3) ? {3'b0, prg_bank[2]} :
                              (bus.sst_addr == 4) ? {3'b0, prg_bank[3]} :
                              (bus.sst_addr == 5) ? chr_bank[0] :
                              (bus.sst_addr == 6) ? chr_bank[1] :
                              (bus.sst_addr == 7) ? chr_bank[2] :
                              (bus.sst_addr == 8) ? chr_bank[3] :
                              (bus.sst_addr == 9) ? chr_bank[4] :
                              (bus.sst_addr == 10) ? chr_bank[5] :
                              (bus.sst_addr == 11) ? chr_bank[6] :
                              (bus.sst_addr == 12) ? chr_bank[7] :
                              (bus.sst_addr == 13) ? {1'b0, wram_select, mirroring, irq_enabled, irq_counter_enable, irq_carry, irq_pending} :
                              (bus.sst_addr == 14) ? irq_counter[7:0] :
                              (bus.sst_addr == 15) ? irq_counter[15:8] :
                              snd_sst;
endmodule
