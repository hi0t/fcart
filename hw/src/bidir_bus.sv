interface bidir_bus;
    logic [7:0] rd_data;
    logic rd_valid;
    logic rd_ready;
    logic [7:0] wr_data;
    logic wr_valid;
    logic wr_ready;
    logic closed;

    modport provider(
        output rd_data,
        output rd_valid,
        input rd_ready,
        input wr_data,
        output wr_valid,
        input wr_ready,
        output closed
    );

    modport consumer(
        input rd_data,
        input rd_valid,
        output rd_ready,
        output wr_data,
        input wr_valid,
        output wr_ready,
        input closed
    );
endinterface
