module chr_rom (
    input logic clk,
    input logic en,
    input logic [7:0] offset,

    sdram_bus.controller ram,

    input logic ce,
    input logic oe,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic [1:0] read_sync;
    logic read_prev;
    logic [2:0][12:0] addr_gray;
    logic [1:0] stable_cnt;
    logic addr_stable;

    assign addr_stable = (stable_cnt == 2'b11);
    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        read_sync <= {read_sync[0], ce && !oe};
        addr_gray <= {addr_gray[1:0], addr ^ (addr >> 1)};
        read_prev <= read_prev & addr_stable;
        ram.req   <= 0;

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
        if (en && !read_prev && addr_stable) begin
            read_prev <= 1;
            ram.we <= 0;
            ram.address <= {{2{1'b0}}, offset, addr[12:1]};
            ram.req <= 1;
        end
    end
endmodule
