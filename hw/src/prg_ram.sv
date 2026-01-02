module prg_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    sdram_bus.controller ram,

    input logic oe,
    input logic [ADDR_BITS-1:0] addr,
    output logic [7:0] data_out
);
    logic [ADDR_BITS-2:0] addr_cached, addr_xor;
    logic [3:0] read_sync;
    logic addr_mismatch;

    always_comb begin
        // XOR all bits and OR the results in a balanced tree
        // This is faster than != which creates a long carry chain
        addr_xor = addr_cached ^ addr[ADDR_BITS-1:1];
        addr_mismatch = |addr_xor;  // Reduction OR is implemented as balanced tree
    end

    initial addr_cached = '1;
    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        ram.req   <= 1'b0;
        read_sync <= {read_sync[2:0], oe};

        if (read_sync[3:1] == 3'b011 && addr_mismatch) begin
            ram.we <= 1'b0;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.req <= 1'b1;
            addr_cached <= addr[ADDR_BITS-1:1];
        end
    end
endmodule
