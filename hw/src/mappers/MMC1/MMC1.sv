module MMC1 (
    map_bus.mapper bus
);
    logic [4:0] shift;
    logic [4:0] shift_next;
    logic [4:0] control;
    logic [4:0] chr_bank_0;
    logic [4:0] chr_bank_1;
    logic [3:0] prg_bank;
    logic delay;
    logic [3:0] prg_sel;
    logic [4:0] chr_sel;

    // CPU
    assign bus.prg_addr = bus.ADDR_BITS'({chr_sel[4], prg_sel, bus.cpu_addr[13:0]});
    assign bus.prg_oe   = bus.cpu_rw && bus.cpu_addr[15];
    // PPU
    assign bus.chr_addr = bus.ADDR_BITS'({bus.args[6] ? {4'b0000, bus.ppu_addr[12]} : chr_sel, bus.ppu_addr[11:0]});
    assign bus.ciram_ce = !bus.ppu_addr[13];
    assign bus.chr_ce   = bus.ciram_ce;
    assign bus.chr_oe   = !bus.ppu_rd;
    assign bus.chr_we   = bus.args[6] ? !bus.ppu_wr : 0;
    assign shift_next   = {bus.cpu_data_in[0], shift[4:1]};

    always_comb begin
        case (control[1:0])
            2'b00: bus.ciram_a10 = 0;
            2'b01: bus.ciram_a10 = 1;
            2'b10: bus.ciram_a10 = bus.ppu_addr[10];
            2'b11: bus.ciram_a10 = bus.ppu_addr[11];
        endcase

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
            delay <= 0;
        end else if (bus.cpu_addr[15] && !bus.cpu_rw && !delay) begin
            if (bus.cpu_data_in[7]) begin
                shift   <= 5'b10000;
                control <= control | 5'b01100;
            end else begin
                if (shift[0]) begin
                    case (bus.cpu_addr[14:13])
                        0: control <= shift_next;
                        1: chr_bank_0 <= shift_next;
                        2: chr_bank_1 <= shift_next;
                        3: prg_bank <= shift_next[3:0];
                    endcase
                    shift <= 5'b10000;
                end else shift <= shift_next;
            end
        end else delay <= 0;
    end
endmodule
