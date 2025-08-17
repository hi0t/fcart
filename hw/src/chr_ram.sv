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
    logic [2:0] write_sync;
    logic read_prev;
    logic [2:0][ADDR_BITS-1:0] addr_gray;
    logic [1:0] stable_cnt;
    logic addr_stable;

    assign addr_stable = (stable_cnt == 2'b11);
    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        read_sync <= {read_sync[0], ce && !oe};
        write_sync <= {write_sync[1:0], ce && we};
        addr_gray <= {addr_gray[1:0], addr ^ (addr >> 1)};
        read_prev <= read_prev & addr_stable;
        ram.req <= 0;

        if (read_sync[1]) begin
            if (addr_gray[2] == addr_gray[1]) begin
                if (stable_cnt != 2'b11) begin
                    stable_cnt <= stable_cnt + 1;
                end
            end else stable_cnt <= 2'b01;
        end else begin
            stable_cnt <= 2'b00;
        end

        // Page mode read divided into atomic transactions. Refresh can be performed at any time.
        if (!read_prev && addr_stable) begin
            read_prev <= 1;
            ram.we <= 0;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.req <= 1;
        end else if (write_sync[2] && !write_sync[1]) begin
            ram.we <= 1;
            ram.address <= addr[ADDR_BITS-1:1];
            ram.data_write <= {data_in, data_in};
            ram.wm <= addr[0] ? 2'b01 : 2'b10;
            ram.req <= 1;

            stable_cnt <= 2'b00;
        end
    end
endmodule
