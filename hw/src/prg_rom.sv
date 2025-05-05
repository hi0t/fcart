module prg_rom #(
    parameter ADDR_BITS = 22
) (
    input logic clk,
    input logic en,

    sdram_bus.master ram,
    output logic refresh,

    input logic m2,
    input logic romsel,
    input logic [14:0] addr,
    output logic [7:0] data
);
    logic [ADDR_BITS-1:0] addr_in;
    logic [2:0] read_sync, refresh_sync;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];
    assign refresh = !refresh_sync[2] && refresh_sync[1];

    always_ff @(negedge romsel) begin
        addr_in <= {{8{1'b0}}, addr[14:1]};
    end

    always_ff @(posedge clk) begin
        read_sync <= {read_sync[1:0], !romsel};
        refresh_sync <= {refresh_sync[1:0], !m2};
        ram.req <= 0;

        if (en && !read_sync[2] && read_sync[1] && (addr_in != ram.address)) begin
            ram.we <= 0;
            ram.address <= addr_in;
            ram.req <= 1;
        end
    end
endmodule
