interface spi_bus;
    logic [7:0] read;  // Word read from SPI
    logic [7:0] write;  // Word to write to SPI
    logic read_valid;  // High pulse when receiving a byte
    logic transm_end;  // Pulse indicating the end of transmission

    modport master(input read, read_valid, transm_end, output write);
    modport slave(input write, output read, read_valid, transm_end);
endinterface
