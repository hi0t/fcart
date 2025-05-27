module chr_rom (
    input logic clk,
    input logic en,

    sdram_bus.controller ram,

    input logic ciram_ce,
    input logic ppu_rd,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic [1:0] read_sync;
    logic read_prev;
    logic [3:0][12:0] addr_sync;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        read_sync <= {read_sync[0], !ppu_rd && ciram_ce};
        addr_sync <= {addr_sync[2:0], addr};
        read_prev <= read_prev & read_sync[1];
        ram.req   <= 0;

        // Page mode read divided into atomic transactions. Refresh can be performed at any time.
        if (en &&
            !read_prev && read_sync[1] &&
            (addr_sync[3] == addr_sync[2]) && (addr_sync[2] == addr_sync[1])) // TODO: check with gray cod
        begin
            read_prev <= read_sync[1];
            ram.we <= 0;
            ram.address <= {{10{1'b0}}, addr_sync[1][12:1]} + 22'h4000;
            ram.req <= 1;
        end
    end
endmodule
