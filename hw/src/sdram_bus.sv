interface sdram_bus #(
    parameter ADDR_BITS = 22  // SDRAM row + col + bank bits
);
    bit req;
    bit ack;
    logic we;
    logic [ADDR_BITS-1:0] address;
    logic [15:0] data_read;
    logic [15:0] data_write;

    modport master(input ack, data_read, output req, we, address, data_write);
    modport slave(input req, we, address, data_write, output ack, data_read);
endinterface
