interface sdram_bus #(
    parameter ADDR_BITS = 22  // SDRAM row + col + bank bits
);
    logic req;
    logic we;
    logic busy;
    logic [ADDR_BITS-1:0] address;
    logic [15:0] data_read;
    logic [15:0] data_write;

    modport memory(input req, we, address, data_write, output busy, data_read);
    modport controller(input busy, data_read, output req, we, address, data_write);
endinterface
