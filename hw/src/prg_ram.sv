module prg_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    sdram_bus.controller ram,
    output logic refresh,

    input logic [ADDR_BITS-1:0] addr,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    input logic oe,
    input logic we
);
    logic [ADDR_BITS-2:0] addr_cached;
    logic [3:0] read_sync;
    logic [3:0] write_sync;
    logic [ADDR_BITS-1:0] addr_d;

    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        addr_d <= addr;
        ram.req <= 1'b0;
        refresh <= 1'b0;
        read_sync <= {read_sync[2:0], oe};
        write_sync <= {write_sync[2:0], we};

        if (read_sync[3:1] == 3'b011) begin
            if (addr_cached != addr_d[ADDR_BITS-1:1]) begin
                ram.we <= 1'b0;
                ram.address <= addr_d[ADDR_BITS-1:1];
                ram.req <= 1'b1;
                addr_cached <= addr_d[ADDR_BITS-1:1];
            end else begin
                refresh <= 1'b1;
            end
        end else if (write_sync[3:1] == 3'b011) begin
            ram.address <= addr_d[ADDR_BITS-1:1];
            ram.wm <= addr_d[0] ? 2'b01 : 2'b10;
        end else if (write_sync[3:1] == 3'b100) begin
            ram.we <= 1'b1;
            ram.data_write <= {data_in, data_in};
            ram.req <= 1'b1;
        end
    end
endmodule
