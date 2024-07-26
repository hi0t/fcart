module fcart (
    input logic CLK,

    //input logic M2,
    input logic [14:0] CPU_ADDR,
    inout wire [7:0] CPU_DATA,
    input logic CPU_RW,
    input logic ROM_CE,
    //output logic IRQ,
    input logic PPU_RD,
    //input logic PPU_WR,
    output logic CIRAM_A10,
    output logic CIRAM_CE,
    input logic [13:0] PPU_ADDR,
    inout wire [7:0] PPU_DATA,
    output logic CPU_DIR,
    output logic PPU_DIR
);
    logic [7:0] prg_rom['h7FFF:0];
    logic [7:0] chr_rom['h1FFF:0];
    logic [7:0] cpu_tx;
    logic [7:0] ppu_tx;
    logic cpu_read;
    logic ppu_read;

    assign cpu_read  = !ROM_CE && CPU_RW;
    assign ppu_read  = !PPU_ADDR[13] && !PPU_RD;
    assign CPU_DATA  = cpu_read ? cpu_tx : 'z;
    assign PPU_DATA  = ppu_read ? ppu_tx : 'z;
    assign CPU_DIR   = cpu_read;
    assign PPU_DIR   = ppu_read;
    assign CIRAM_CE  = !PPU_ADDR[13];
    assign CIRAM_A10 = PPU_ADDR[10];

    initial begin
        $readmemh("../../rom/prg.mem", prg_rom);
        $readmemh("../../rom/chr.mem", chr_rom);
    end

    always_ff @(negedge ROM_CE) cpu_tx <= prg_rom[CPU_ADDR];
    always_ff @(negedge PPU_RD) ppu_tx <= chr_rom[PPU_ADDR[12:0]];
endmodule
