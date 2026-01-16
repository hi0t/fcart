module prg_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    sdram_bus.controller ram,

    input logic [ADDR_BITS-1:0] addr,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    input logic oe,
    input logic we
);
    logic [ADDR_BITS-2:0] addr_cached, addr_xor;
    logic [3:0] read_sync;
    logic [3:0] write_sync;
    logic addr_mismatch;

    always_comb begin
        // XOR all bits and OR the results in a balanced tree
        // This is faster than != which creates a long carry chain
        addr_xor = addr_cached ^ addr[ADDR_BITS-1:1];
        addr_mismatch = |addr_xor;  // Reduction OR is implemented as balanced tree
    end

    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        ram.req <= 1'b0;
        read_sync <= {read_sync[2:0], oe};
        write_sync <= {write_sync[2:0], we};

        if (read_sync[3:1] == 3'b011 && addr_mismatch) begin
            ram.we <= 1'b0;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.req <= 1'b1;
            addr_cached <= addr[ADDR_BITS-1:1];
        end else if (write_sync[3:1] == 3'b100) begin
            ram.we <= 1'b1;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.data_write <= {data_in, data_in};
            ram.wm <= addr[0] ? 2'b01 : 2'b10;
            ram.req <= 1'b1;
        end
    end
endmodule
