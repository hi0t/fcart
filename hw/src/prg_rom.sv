module prg_rom (
    input logic clk,
    input logic en,

    sdram_bus.master ram,
    output logic refresh,

    input logic m2,
    input logic romsel,
    input logic [14:0] addr,
    output logic [7:0] data
);
    bit read_req, read_ack;
    logic [ 1:0] read_req_sync;
    logic [13:0] addr_in;
    bit refresh_req, refresh_ack;
    logic [1:0] refresh_req_sync;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(negedge romsel) begin
        if (addr_in != addr[14:1]) begin
            read_req <= !read_req;
            addr_in  <= addr[14:1];
        end
    end

    always_ff @(negedge m2) begin
        refresh_req <= !refresh_req;
    end

    always_ff @(posedge clk) begin
        read_req_sync <= {read_req_sync[0], read_req};
        refresh_req_sync <= {refresh_req_sync[0], refresh_req};
        refresh <= 0;

        if (read_req_sync[1] != read_ack) begin
            read_ack <= read_req_sync[1];

            if (en) begin
                ram.we <= 0;
                ram.address <= {{8{1'b0}}, addr_in};
                ram.req <= !ram.req;
            end
        end

        if (refresh_req_sync[1] != refresh_ack) begin
            refresh_ack <= refresh_req_sync[1];
            refresh <= 1;
        end
    end
endmodule
