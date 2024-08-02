interface sdram_bus #(
    parameter ADDR_BITS,
    parameter DATA_BITS
) (
    input logic clk
);
    logic read;
    logic write;
    logic [ADDR_BITS-1:0] address;
    logic [DATA_BITS-1:0] data_read;
    logic [DATA_BITS-1:0] data_write;
    logic busy;
    logic refresh = 0;  // Forces a refresh on a falling edge

    logic [1:0] read_sync, write_sync;
    logic [2:0] refresh_sync;
    logic read_buf, write_buf, refresh_buf;

    modport host(
        input read_buf, write_buf, address, data_write, refresh_buf,
        output data_read, busy
    );
    modport device(output read, write, address, data_write, refresh, input data_read, busy);

    always_ff @(posedge clk) begin
        // Synchronization of signals from other clock domains.
        read_sync <= {read_sync[0], read};
        read_buf <= read_sync[1];

        write_sync <= {write_sync[0], write};
        write_buf <= write_sync[1];

        refresh_sync <= {refresh_sync[1:0], refresh};
        refresh_buf <= !refresh_sync[1] && refresh_sync[2];
    end
endinterface
