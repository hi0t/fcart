interface sdram_bus #(
    parameter ADDR_BITS = 22
);
    logic req;
    logic we;  // write enable
    logic [1:0] wm;  // write mask
    logic [ADDR_BITS-1:0] address;
    logic [15:0] data_read;
    logic [15:0] data_write;

    modport memory(input req, we, wm, address, data_write, output data_read);
    modport controller(input data_read, output req, we, wm, address, data_write);
endinterface
