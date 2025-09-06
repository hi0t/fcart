module prg_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    input logic reset,
    sdram_bus.controller ram,

    input logic oe,
    input logic [ADDR_BITS-1:0] addr,
    output logic [7:0] data_out
);
    logic [ADDR_BITS-2:0] addr_cached;
    logic [3:0] read_sync;

    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        if (reset) begin
            ram.req <= 0;
            ram.we <= 0;
            addr_cached <= '1;
            read_sync <= '0;
        end else begin
            read_sync <= {read_sync[2:0], oe};

            if (ram.req == ram.ack && read_sync[3:1] == 3'b011 && addr_cached != addr[ADDR_BITS-1:1]) begin
                ram.we <= 0;
                ram.address <= addr[ADDR_BITS-1:1];
                ram.req <= !ram.req;
                addr_cached <= addr[ADDR_BITS-1:1];
            end
        end
    end

    // Verilator lint_off UNUSED
    logic debug_ram_busy = ram.req != ram.ack;
    // Verilator lint_on UNUSED
endmodule
