module loader (
    map_bus.mapper bus
);
    logic [7:0] rom[1024]  /* synthesis syn_romstyle = "EBR" */;
    initial $readmemh("loader/loader.mem", rom);

    assign bus.cpu_oe = 1;
    assign bus.prg_oe = bus.cpu_rw && bus.cpu_addr[15];
    assign bus.ciram_a10 = bus.ppu_addr[10];
    assign bus.ciram_ce = !bus.ppu_addr[13];

    always_ff @(posedge bus.m2) begin
        if (bus.cpu_rw) begin
            bus.cpu_data_out <= rom[bus.cpu_addr[9:0]];
        end
    end
endmodule
