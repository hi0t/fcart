`include "mappers/map.svh"

module rom (
    input logic clk,

    input  map::in  in,
    output map::out out,

    sdram_bus.device prg_ram,
    sdram_bus.device chr_ram,
    sdio_bus.device  sdio,

    output logic [7:0] prg_data,
    output logic [7:0] chr_data
);
    logic [9:0] mapper_id = 10'h3FF;

    always_comb begin
        case (mapper_id)
            0: out = nrom_out;
            default: out = generic_out;
        endcase

        if (mapper_id == 10'h3FF) prg_data = generic_prg_data;
        else prg_data = out.prg_ram.addr[0] ? prg_data_cache[15:8] : prg_data_cache[7:0];
    end

    /***************************************/
    /* Name: generic                       */
    /* ID  : 1024                          */
    /***************************************/
    map::out generic_out;
    logic [7:0] generic_prg_data;
    generic generic (
        .in(in),
        .out(generic_out),
        .sdio(sdio),
        .prg_data(generic_prg_data)
    );

    /***************************************/
    /* Name: NROM                          */
    /* ID  : 0                             */
    /***************************************/
    map::out nrom_out;
    nrom nrom (
        .in (in),
        .out(nrom_out)
    );


    logic prg_req = 0, chr_req = 0;
    logic [1:0] prg_req_sync, chr_req_sync;
    logic [map::ADDR_BITS-2:0] prg_addr_cache;
    logic [15:0] prg_data_cache;
    logic prg_addr_differ;

    // Connect the mapper bus to the SDRAM
    assign prg_ram.req = prg_req_sync[1];
    assign prg_data_cache = prg_ram.data_read;
    assign prg_addr_differ = prg_addr_cache != out.prg_ram.addr[map::ADDR_BITS-1:1];
    assign prg_ram.data_write = out.prg_ram.data16;

    assign chr_ram.req = chr_req_sync[1];
    assign chr_data = out.chr_ram.addr[0] ? chr_ram.data_read[15:8] : chr_ram.data_read[7:0];
    assign chr_ram.data_write = out.chr_ram.data16;

    // Synch of requests with SDRAM clock domain
    always_ff @(posedge clk) begin
        prg_req_sync <= {prg_req_sync[0], prg_req};
        chr_req_sync <= {chr_req_sync[0], chr_req};
    end

    // Latch read/write requests from the CPU bus
    always_ff @(posedge out.prg_ram.oe) begin
        if (out.prg_ram.we || prg_addr_differ) begin
            prg_req <= !prg_req;
            prg_ram.address <= out.prg_ram.addr[map::ADDR_BITS-1:1];
        end

        if (prg_addr_differ) prg_addr_cache <= out.prg_ram.addr[map::ADDR_BITS-1:1];

        prg_ram.we <= out.prg_ram.we;
    end

    // Latch read/write requests from the PPU bus
    always_ff @(posedge out.chr_ram.oe) begin
        chr_req <= !chr_req;
        chr_ram.address <= out.chr_ram.addr[map::ADDR_BITS-1:1];
        chr_ram.we <= out.chr_ram.we;
    end
endmodule
