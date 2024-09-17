`ifndef MAP_SVH_
`define MAP_SVH_

package map;
    localparam ADDR_BITS = 24;

    typedef struct {
        logic [ADDR_BITS-1:0] addr;
        logic [15:0] data16;
        logic oe;
        logic we;
    } ram;

    typedef struct {
        logic m2;
        logic [14:0] cpu_addr;
        logic [7:0] cpu_data;
        logic cpu_rw;
        logic rom_ce;

        logic [13:0] ppu_addr;
        logic [7:0] ppu_data;
        logic ppu_rd;
        logic ppu_wr;
    } in;

    typedef struct {
        logic ciram_a10;
        logic ciram_ce;

        ram prg_ram;
        ram chr_ram;
    } out;
endpackage

`endif
