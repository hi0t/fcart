interface qspi_bus;
    logic [7:0] cmd;  // Command read from QSPI
    logic cmd_ready;  // Pulse to indicate command is ready
    logic [7:0] data_read;  // Word read from QSPI
    logic data_ready;  // Pulse to indicate data is ready
    logic [7:0] data_write;  // Word to write to QSPI
    logic can_write;  // Pulse to indicate we can write
    logic we;  // Start write

    modport master(input cmd, cmd_ready, data_read, data_ready, can_write, output data_write, we);
    modport slave(input data_write, we, output cmd, cmd_ready, data_read, data_ready, can_write);
endinterface
