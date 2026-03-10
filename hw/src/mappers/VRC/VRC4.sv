module VRC4 (
    map_bus.mapper bus
);
    logic [5:0] prg_bank[2];  // $8000, $A000
    logic [8:0] chr_bank[8];
    logic [1:0] mirroring;
    logic swap_mode;
    logic [7:0] irq_latch_reg;

    // Address decoding
    logic [1:0] low_bits;
    always_comb begin
        case (bus.submapper)
            3'd0: low_bits = {bus.cpu_addr[2], bus.cpu_addr[1]}; // 21: A2, A1
            3'd1: low_bits = {bus.cpu_addr[0], bus.cpu_addr[1]}; // 22: A1, A0
            3'd2: low_bits = {bus.cpu_addr[1], bus.cpu_addr[0]}; // 23, 25: A0, A1
            3'd3: low_bits = {bus.cpu_addr[1], bus.cpu_addr[0]}; // 27: A0, A1
            default: low_bits = bus.cpu_addr[1:0];
        endcase
    end

    logic write_en;
    assign write_en = bus.cpu_addr[15] && !bus.cpu_rw;

    // PRG Banking
    logic [5:0] bank_8000, bank_A000, bank_C000;
    always_comb begin
        if (swap_mode) begin
            bank_8000 = 6'b111110;  // -2
            bank_A000 = prg_bank[1];
            bank_C000 = prg_bank[0];
        end else begin
            bank_8000 = prg_bank[0];
            bank_A000 = prg_bank[1];
            bank_C000 = 6'b111110;  // -2
        end
    end

    always_comb begin
        if (bus.cpu_addr[15]) begin
            case (bus.cpu_addr[14:13])
                2'b00: bus.prg_addr = bus.ADDR_BITS'({bank_8000, bus.cpu_addr[12:0]}); // $8000
                2'b01: bus.prg_addr = bus.ADDR_BITS'({bank_A000, bus.cpu_addr[12:0]}); // $A000
                2'b10: bus.prg_addr = bus.ADDR_BITS'({bank_C000, bus.cpu_addr[12:0]}); // $C000
                2'b11: bus.prg_addr = bus.ADDR_BITS'({6'b111111, bus.cpu_addr[12:0]}); // $E000
            endcase
            bus.prg_we = 0;
        end else begin
            // WRAM or System
            bus.prg_addr = bus.ADDR_BITS'(bus.cpu_addr[12:0]);
            bus.prg_we   = !bus.cpu_rw && bus.wram_ce;
        end
    end

    assign bus.wram_ce = (bus.cpu_addr[15:13] == 3'b011);
    assign bus.prg_oe  = bus.cpu_rw && (bus.cpu_addr[15] || bus.wram_ce);

    // PPU
    logic [8:0] selected_chr_bank;
    assign selected_chr_bank = chr_bank[bus.ppu_addr[12:10]];
    assign bus.chr_addr = bus.ADDR_BITS'({selected_chr_bank, bus.ppu_addr[9:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce = bus.ciram_ce;
    assign bus.chr_we = bus.chr_ram ? !bus.ppu_wr : 0;
    assign bus.chr_oe = !bus.ppu_rd;

    // Mirroring
    always_comb begin
        case (mirroring)
            0: bus.ciram_a10 = bus.ppu_addr[10]; // V
            1: bus.ciram_a10 = bus.ppu_addr[11]; // H
            2: bus.ciram_a10 = 0;
            3: bus.ciram_a10 = 1;
        endcase
    end

    assign bus.prg_ce = 1;
    assign bus.audio  = 0;

    // Write Logic
    logic [7:0] next_irq_latch;

    always_comb begin
        next_irq_latch = irq_latch_reg;
        if (write_en && bus.cpu_addr[15:12] == 4'hF) begin
            if (low_bits == 0) next_irq_latch[3:0] = bus.cpu_data_in[3:0];
            if (low_bits == 1) next_irq_latch[7:4] = bus.cpu_data_in[3:0];
        end
    end

    always_ff @(negedge bus.m2) begin
        if (bus.reset) begin
            prg_bank[0] <= '0;
            prg_bank[1] <= '0;
            mirroring <= '0;
            swap_mode <= '0;
            chr_bank <= '{default: 0};
            irq_latch_reg <= '0;
        end else if (bus.sst_enable) begin
            if (bus.sst_we) begin
                case (bus.sst_addr)
                    0: prg_bank[0] <= bus.sst_data_in[5:0];
                    1: prg_bank[1] <= bus.sst_data_in[5:0];
                    2: {swap_mode, mirroring} <= bus.sst_data_in[2:0];
                    3: irq_latch_reg <= bus.sst_data_in;
                    21: chr_bank[0][7:0] <= bus.sst_data_in;
                    22: chr_bank[0][8]   <= bus.sst_data_in[0];
                    23: chr_bank[1][7:0] <= bus.sst_data_in;
                    24: chr_bank[1][8]   <= bus.sst_data_in[0];
                    25: chr_bank[2][7:0] <= bus.sst_data_in;
                    26: chr_bank[2][8]   <= bus.sst_data_in[0];
                    27: chr_bank[3][7:0] <= bus.sst_data_in;
                    28: chr_bank[3][8]   <= bus.sst_data_in[0];
                    29: chr_bank[4][7:0] <= bus.sst_data_in;
                    30: chr_bank[4][8]   <= bus.sst_data_in[0];
                    31: chr_bank[5][7:0] <= bus.sst_data_in;
                    32: chr_bank[5][8]   <= bus.sst_data_in[0];
                    33: chr_bank[6][7:0] <= bus.sst_data_in;
                    34: chr_bank[6][8]   <= bus.sst_data_in[0];
                    35: chr_bank[7][7:0] <= bus.sst_data_in;
                    36: chr_bank[7][8]   <= bus.sst_data_in[0];
                endcase
            end
        end else if (write_en) begin
            case (bus.cpu_addr[14:12])
                3'b000: begin  // $8000
                    if (low_bits == 0) prg_bank[0] <= bus.cpu_data_in[5:0];
                end
                3'b001: begin  // $9000
                    if (low_bits == 0) mirroring <= bus.cpu_data_in[1:0];
                    if (low_bits == 2) swap_mode <= bus.cpu_data_in[1];
                end
                3'b010: begin  // $A000
                    if (low_bits == 0) prg_bank[1] <= bus.cpu_data_in[5:0];
                end
                3'b011: begin  // $B000
                    if (low_bits == 0) chr_bank[0][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 1) chr_bank[0][8:4] <= bus.cpu_data_in[4:0];
                    if (low_bits == 2) chr_bank[1][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 3) chr_bank[1][8:4] <= bus.cpu_data_in[4:0];
                end
                3'b100: begin  // $C000
                    if (low_bits == 0) chr_bank[2][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 1) chr_bank[2][8:4] <= bus.cpu_data_in[4:0];
                    if (low_bits == 2) chr_bank[3][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 3) chr_bank[3][8:4] <= bus.cpu_data_in[4:0];
                end
                3'b101: begin  // $D000
                    if (low_bits == 0) chr_bank[4][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 1) chr_bank[4][8:4] <= bus.cpu_data_in[4:0];
                    if (low_bits == 2) chr_bank[5][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 3) chr_bank[5][8:4] <= bus.cpu_data_in[4:0];
                end
                3'b110: begin  // $E000
                    if (low_bits == 0) chr_bank[6][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 1) chr_bank[6][8:4] <= bus.cpu_data_in[4:0];
                    if (low_bits == 2) chr_bank[7][3:0] <= bus.cpu_data_in[3:0];
                    if (low_bits == 3) chr_bank[7][8:4] <= bus.cpu_data_in[4:0];
                end
                3'b111: begin  // $F000
                    irq_latch_reg <= next_irq_latch;
                end
            endcase
        end
    end

    // IRQ
    logic [7:0] irq_data_mux;
    assign irq_data_mux = (low_bits == 2) ? bus.cpu_data_in : next_irq_latch;
    logic [7:0] irq_sst_out;

    vrc_irq vrc_irq (
        .clk(bus.m2),
        .reset(bus.reset),
        .cpu_data_in(irq_data_mux),
        .wr_latch(write_en && bus.cpu_addr[15:12] == 4'hF && (low_bits == 0 || low_bits == 1)),
        .wr_ctrl(write_en && bus.cpu_addr[15:12] == 4'hF && low_bits == 2),
        .wr_ack(write_en && bus.cpu_addr[15:12] == 4'hF && low_bits == 3),
        .irq(bus.irq),
        .sst_enable(bus.sst_enable),
        .sst_we(bus.sst_we),
        .sst_addr(bus.sst_addr),
        .sst_data_in(bus.sst_data_in),
        .sst_data_out(irq_sst_out)
    );

    // Save State Output
    always_comb begin
        case (bus.sst_addr)
            0: bus.sst_data_out = {2'b0, prg_bank[0]};
            1: bus.sst_data_out = {2'b0, prg_bank[1]};
            2: bus.sst_data_out = {5'b0, swap_mode, mirroring};
            3: bus.sst_data_out = irq_latch_reg;
            16, 17, 18, 19, 20: bus.sst_data_out = irq_sst_out;
            21: bus.sst_data_out = chr_bank[0][7:0];
            22: bus.sst_data_out = {7'b0, chr_bank[0][8]};
            23: bus.sst_data_out = chr_bank[1][7:0];
            24: bus.sst_data_out = {7'b0, chr_bank[1][8]};
            25: bus.sst_data_out = chr_bank[2][7:0];
            26: bus.sst_data_out = {7'b0, chr_bank[2][8]};
            27: bus.sst_data_out = chr_bank[3][7:0];
            28: bus.sst_data_out = {7'b0, chr_bank[3][8]};
            29: bus.sst_data_out = chr_bank[4][7:0];
            30: bus.sst_data_out = {7'b0, chr_bank[4][8]};
            31: bus.sst_data_out = chr_bank[5][7:0];
            32: bus.sst_data_out = {7'b0, chr_bank[5][8]};
            33: bus.sst_data_out = chr_bank[6][7:0];
            34: bus.sst_data_out = {7'b0, chr_bank[6][8]};
            35: bus.sst_data_out = chr_bank[7][7:0];
            36: bus.sst_data_out = {7'b0, chr_bank[7][8]};
            default: bus.sst_data_out = 0;
        endcase
    end

endmodule
