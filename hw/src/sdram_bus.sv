interface sdram_bus #(
    parameter ADDR_BITS
);
    logic req = 0;
    logic ack = 0;
    logic we;
    logic [ADDR_BITS-1:0] address;
    logic [15:0] data_read;
    logic [15:0] data_write;
    logic refresh = 0;

    modport host(input req, we, address, data_write, refresh, output ack, data_read);
    modport device(output req, we, address, data_write, refresh, input ack, data_read);
endinterface
