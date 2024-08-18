module chr_rom #(
    parameter ADDR_BITS
) (
    input logic clk,
    input logic enable,

    sdram_bus.device ram,
    input logic [ADDR_BITS-1:0] offset,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);

    logic [1:0] ppu_rd_sync;
    logic [1:0] ciram_ce_sync;
    logic [6:0][12:0] addr_sync;
    logic [12:0] addr_prev;
    logic [ADDR_BITS-1:0] addr_in;
    logic addr_stable;
    logic low_bit;
    bit start_read = 1;

    // Intermediate state filter during address switching
    assign addr_stable = (addr_sync[0] == addr_sync[1] &&
        addr_sync[0] == addr_sync[2] &&
        addr_sync[0] == addr_sync[3] &&
        addr_sync[0] == addr_sync[4] &&
        addr_sync[0] == addr_sync[5] &&
        addr_sync[0] == addr_sync[6]);
    assign ram.data_write = 'x;
    assign addr_in = {{ADDR_BITS - 13{1'b0}}, addr_sync[0]} | offset;

    // Requests to ROM via PPU bus
    always_ff @(posedge clk) begin
        ppu_rd_sync <= {ppu_rd_sync[0], ppu_rd};
        ciram_ce_sync <= {ciram_ce_sync[0], ciram_ce};
        addr_sync <= {addr_sync[5:0], addr};

        if (!enable) start_read <= 1;
        else begin
            if (start_read) begin
                // We prepare data before the PPU switches to reading mode
                if (ppu_rd_sync[1] && ciram_ce_sync[1] && addr_stable && addr_sync[0] != addr_prev) begin
                    low_bit <= addr_in[0];
                    ram.address <= addr_in[ADDR_BITS-1:1];
                    ram.we <= 0;
                    ram.req <= ~ram.req;
                    start_read <= 0;
                    addr_prev <= addr_sync[0];
                end
            end else begin
                if (ram.req == ram.ack) begin
                    data <= low_bit ? ram.data_read[15:8] : ram.data_read[7:0];
                    start_read <= 1;
                end
            end
        end
    end
endmodule
