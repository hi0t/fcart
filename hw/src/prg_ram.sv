module prg_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    sdram_bus.controller ram,

    input logic oe,
    input logic [ADDR_BITS-1:0] addr,
    output logic [7:0] data_out
);
    logic [ADDR_BITS-2:0] addr_cached;
    logic [1:0] oe_sync;
    logic read_prev;

    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        oe_sync   <= {oe_sync[0], oe};
        read_prev <= read_prev & oe_sync[1];
        ram.req   <= 0;

        if (!read_prev && oe_sync[1] && (addr_cached != addr[ADDR_BITS-1:1])) begin
            read_prev <= 1;
            ram.we <= 0;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.req <= 1;
            addr_cached <= addr[ADDR_BITS-1:1];
        end
    end
endmodule
