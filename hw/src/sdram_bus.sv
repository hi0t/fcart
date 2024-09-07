interface sdram_bus #(
    parameter ADDR_BITS
);
    bit req;
    bit ack;
    logic we;
    logic [ADDR_BITS-1:0] address;
    logic [15:0] data_read;
    logic [15:0] data_write;

    modport host(input req, we, address, data_write, output ack, data_read);
    modport device(output req, we, address, data_write, input ack, data_read);
endinterface
