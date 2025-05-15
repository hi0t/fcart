interface bidir_bus;
    logic [7:0] rd_data;
    logic rd_en;
    logic rd_empty;
    logic [7:0] wr_data;
    logic wr_en;
    logic wr_full;
    logic closed;

    modport provider(
        output rd_data,
        input rd_en,
        output rd_empty,
        input wr_data,
        input wr_en,
        output wr_full,
        output closed
    );

    modport consumer(
        input rd_data,
        output rd_en,
        input rd_empty,
        output wr_data,
        output wr_en,
        input wr_full,
        input closed
    );
endinterface
