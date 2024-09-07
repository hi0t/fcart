module prg_rom #(
    parameter ADDR_BITS
) (
    input logic clk,

    sdram_bus.device ram,

    input logic m2,
    input logic cpu_rw,
    input logic rom_ce,
    input logic [14:0] addr,
    output logic [7:0] data
);
    logic read;
    logic ram_req = 0;
    logic [1:0] ram_req_sync;
    logic [ADDR_BITS-1:0] addr_in;
    logic [11:0] addr_cache;
    logic [15:0] data_cache;

    assign read = !rom_ce && cpu_rw && m2;
    assign ram.req = ram_req_sync[1];
    assign ram.we = 0;
    assign ram.address = addr_in[ADDR_BITS-1:1];
    assign data = addr_in[0] ? data_cache[15:8] : data_cache[7:0];
    assign data_cache = ram.data_read;

    always_ff @(posedge read) begin
        if (addr_cache != addr[12:1]) begin
            ram_req <= !ram_req;
            addr_cache <= addr[12:1];
        end
        addr_in <= {{ADDR_BITS - 15{1'b0}}, addr};
    end

    always_ff @(posedge clk) begin
        ram_req_sync <= {ram_req_sync[0], ram_req};
    end
endmodule
