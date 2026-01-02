module chr_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    sdram_bus.controller ram,

    input logic [ADDR_BITS-1:0] addr,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    input logic ce,
    input logic oe,
    input logic we
);
    logic [1:0] read_sync;
    logic [3:0] write_sync;
    logic [2:0][ADDR_BITS-1:0] addr_gray;
    logic [2:0] match_addr;

    initial addr_gray = '1;
    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        ram.req <= 1'b0;
        read_sync <= {read_sync[0], ce && !oe};
        write_sync <= {write_sync[2:0], ce && we};
        addr_gray <= {addr_gray[1:0], addr ^ (addr >> 1)};

        if (read_sync[1] && addr_gray[2] == addr_gray[1]) begin
            match_addr <= {match_addr[1:0], 1'b1};
        end else begin
            match_addr <= '0;
        end

        if (match_addr == 3'b011) begin
            ram.we <= 1'b0;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.req <= 1'b1;
        end else if (write_sync[3:1] == 3'b100) begin
            ram.we <= 1'b1;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.data_write <= {data_in, data_in};
            ram.wm <= addr[0] ? 2'b01 : 2'b10;
            ram.req <= 1'b1;
        end
    end
endmodule
