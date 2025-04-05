interface spi_bus;
    logic [7:0] data_read;  // Word read from SPI
    logic read_valid;  // The pulse that initiates that data is ready to be read
    logic [7:0] data_write;  // Word to write to SPI
    logic can_write;  // The pulse that initiates the next word can be written

    modport master(input data_read, read_valid, can_write, output data_write);
    modport slave(input data_write, output data_read, read_valid, can_write);
endinterface
