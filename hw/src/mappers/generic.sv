`include "map.svh"

module generic (
    input map::in in,
    output map::out out,
    sdio_bus.device sdio,
    output logic [7:0] prg_data
);
    localparam CTRL_RST = 8'b11111110;

    // Controls the state of the cartridge menu (0x4020).
    // XXXXXXXXX
    //         |
    //         Updating the nametable
    logic [7:0] ctrl_reg[4];
    logic [7:0] rom[256];
    logic [7:0] nametable[1024];
    logic [7:0] palette[32];

    assign out.prg_ram.addr = {{map::ADDR_BITS - 15{1'b0}}, in.cpu_addr};
    assign out.prg_ram.oe = !in.rom_ce;
    assign out.prg_ram.we = !in.cpu_rw;

    assign out.chr_ram.addr = {{map::ADDR_BITS - 13{1'b0}}, in.ppu_addr[12:0]};
    assign out.chr_ram.oe = !in.ppu_addr[13] && (!in.ppu_rd || !in.ppu_wr);
    assign out.chr_ram.we = !in.ppu_wr;
    assign out.ciram_a10 = in.ppu_addr[10];
    assign out.ciram_ce = !in.ppu_addr[13];

    initial $readmemh(`NESROM_PATH, rom);

    always_ff @(posedge in.m2) begin
        if (in.cpu_rw) begin
            if (in.cpu_addr == 'h4020) begin
                prg_data <= ctrl_reg[0];
                ctrl_reg[0] <= ctrl_reg[0] & CTRL_RST;
            end else if (!in.rom_ce) begin
                prg_data <= rom[in.cpu_addr[7:0]];
            end
        end
    end

    always_ff @(posedge sdio.clk) begin
        sdio.resp_valid <= 0;

        if (sdio.req_valid) begin
            case (sdio.req_cmd)
                1: begin

                end
                default: sdio.resp_valid <= 2;
            endcase
        end
    end
endmodule
