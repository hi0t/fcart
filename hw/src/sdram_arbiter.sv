module sdram_arbiter (
    input logic write_active,

    sdram_bus.host api_prg,
    sdram_bus.host api_chr,

    sdram_bus.host fc_prg,
    sdram_bus.host fc_chr,

    sdram_bus.device ch0,
    sdram_bus.device ch1
);

    assign ch0.req = write_active ? api_prg.req : fc_prg.req;
    assign ch0.we = write_active ? api_prg.we : fc_prg.we;
    assign ch0.address = write_active ? api_prg.address : fc_prg.address;
    assign ch0.data_write = write_active ? api_prg.data_write : fc_prg.data_write;
    assign api_prg.ack = write_active ? ch0.ack : 'x;
    assign api_prg.data_read = write_active ? ch0.data_read : 'x;
    assign fc_prg.ack = write_active ? 'x : ch0.ack;
    assign fc_prg.data_read = write_active ? 'x : ch0.data_read;

    assign ch1.req = write_active ? api_chr.req : fc_chr.req;
    assign ch1.we = write_active ? api_chr.we : fc_chr.we;
    assign ch1.address = write_active ? api_chr.address : fc_chr.address;
    assign ch1.data_write = write_active ? api_chr.data_write : fc_chr.data_write;
    assign api_chr.ack = write_active ? ch1.ack : 'x;
    assign api_chr.data_read = write_active ? ch1.data_read : 'x;
    assign fc_chr.ack = write_active ? 'x : ch1.ack;
    assign fc_chr.data_read = write_active ? 'x : ch1.data_read;

endmodule
