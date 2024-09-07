module chr_rom #(
    parameter ADDR_BITS
) (
    input logic clk,

    sdram_bus.device ram,
    output logic refresh,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic read;
    logic ram_req = 0;
    logic [1:0] ram_req_sync;
    logic [2:0][12:0] addr_sync;
    logic [ADDR_BITS-1:0] addr_in;


    assign read = !ppu_rd && ciram_ce;
    assign ram.req = ram_req_sync[1];
    assign ram.we = 0;
    assign ram.address = addr_in[ADDR_BITS-1:1];
    assign data = addr_in[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge read) begin
        ram_req <= !ram_req;
        addr_in <= {{ADDR_BITS - 13{1'b0}}, addr};
    end

    always_ff @(posedge clk) begin
        ram_req_sync <= {ram_req_sync[0], ram_req};
        addr_sync <= {addr_sync[1:0], addr};
        // Before reading, the PPU sets a new address.
        // This event will fall into the update window,
        // which will ensure that it does not overlap with access to the PPU memory.
        refresh <= addr_sync[2] != addr_sync[1];
    end
endmodule
