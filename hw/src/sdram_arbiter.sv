module sdram_arbiter (
    input logic api_active,

    sdram_bus.host api_prg,
    sdram_bus.host api_chr,

    sdram_bus.host fc_prg,
    sdram_bus.host fc_chr,

    sdram_bus.device ch0,
    sdram_bus.device ch1
);

    assign ch0.req = api_active ? api_prg.req : fc_prg.req;
    assign ch0.we = api_active ? api_prg.we : fc_prg.we;
    assign ch0.address = api_active ? api_prg.address : fc_prg.address;
    assign ch0.data_write = api_active ? api_prg.data_write : fc_prg.data_write;

    assign api_prg.ack = api_active ? ch0.ack : api_prg.ack;
    assign api_prg.data_read = api_active ? ch0.data_read : 'x;
    assign fc_prg.ack = api_active ? fc_prg.ack : ch0.ack;
    assign fc_prg.data_read = api_active ? 'x : ch0.data_read;

    assign ch1.req = api_active ? api_chr.req : fc_chr.req;
    assign ch1.we = api_active ? api_chr.we : fc_chr.we;
    assign ch1.address = api_active ? api_chr.address : fc_chr.address;
    assign ch1.data_write = api_active ? api_chr.data_write : fc_chr.data_write;

    assign api_chr.ack = api_active ? ch1.ack : api_chr.ack;
    assign api_chr.data_read = api_active ? ch1.data_read : 'x;
    assign fc_chr.ack = api_active ? fc_chr.ack : ch1.ack;
    assign fc_chr.data_read = api_active ? 'x : ch1.data_read;
endmodule
