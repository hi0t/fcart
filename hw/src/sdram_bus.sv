interface sdram_bus #(
    parameter ADDR_BITS,
    parameter DATA_BITS
);
    logic read;
    logic write;
    logic [ADDR_BITS-1:0] address;
    logic [DATA_BITS-1:0] data_read;
    logic [DATA_BITS-1:0] data_write;
    logic busy;

    modport host(input read, write, address, data_write, output data_read, busy);
    modport device(output read, write, address, data_write, input data_read, busy);
endinterface
