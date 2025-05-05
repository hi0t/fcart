module chr_rom #(
    parameter ADDR_BITS = 22
) (
    input logic clk,
    input logic en,

    sdram_bus.master ram,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic [2:0] read_sync;
    logic [ADDR_BITS-1:0] addr_in;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(negedge ppu_rd) begin
        if (ciram_ce) addr_in <= {{10{1'b0}}, addr[12:1]} + 22'h4000;
    end

    always_ff @(posedge clk) begin
        read_sync <= {read_sync[1:0], !ppu_rd && ciram_ce};
        ram.req   <= 0;

        if (en && !read_sync[2] && read_sync[1] && (addr_in != ram.address)) begin
            ram.we <= 0;
            ram.address <= addr_in;
            ram.req <= 1;
        end
    end
endmodule
