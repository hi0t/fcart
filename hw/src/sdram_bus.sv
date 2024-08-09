interface sdram_bus #(
    parameter ADDR_BITS,
    parameter WIDE = 0,
    parameter FILTER = 0
) (
    input logic clk
);
    localparam USER_ADDR_BITS = ADDR_BITS - WIDE;

    logic read;
    logic write;
    logic refresh;
    logic [USER_ADDR_BITS-1:0] address;
    logic [7+8*WIDE:0] data_read;
    logic [7+8*WIDE:0] data_write;
    logic busy;

    logic read_req, write_req, refresh_req;
    logic [2:0] read_sync, write_sync, refresh_sync;

    logic [4:0] cnt = 0;
    logic strobe = 1;

    assign read_req = (read_sync[2:1] == 2'b01 && strobe);
    assign write_req = (write_sync[2:1] == 2'b01);
    assign refresh_req = (refresh_sync[2:1] == 2'b01);

    modport host(
        input read_req, write_req, refresh_req, address, data_write,
        output data_read, busy
    );
    modport device(output read, write, refresh, address, data_write, input data_read, busy);

    always_ff @(posedge clk) begin
        // Synchronization of signals from other clock domains.
        read_sync <= {read_sync[1:0], read};
        write_sync <= {write_sync[1:0], write};
        refresh_sync <= {refresh_sync[1:0], refresh};

        if (FILTER == 1) begin
            cnt <= cnt + 1;
            if (!strobe && cnt == 20) strobe <= 1;
            if (read_req) begin
                cnt <= 0;
                strobe <= 0;
            end
        end else strobe <= 1;
    end
endinterface
