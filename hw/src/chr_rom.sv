module chr_rom (
    input logic clk,
    input logic en,

    sdram_bus.master ram,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);
    bit read_req, read_ack;
    logic [ 1:0] read_req_sync;
    logic [11:0] addr_in;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(negedge ppu_rd) begin
        if (ciram_ce) begin
            read_req <= !read_req;
            addr_in  <= addr[12:1];
        end
    end

    always_ff @(posedge clk) begin
        read_req_sync <= {read_req_sync[0], read_req};

        if (read_req_sync[1] != read_ack) begin
            read_ack <= read_req_sync[1];

            if (en) begin
                ram.we <= 0;
                ram.address <= {{10{1'b0}}, addr_in} + 22'h4000;
                ram.req <= !ram.req;
            end
        end
    end
endmodule
