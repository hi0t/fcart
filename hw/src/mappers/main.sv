module main (
    map_bus.mapper bus
);
    assign bus.ciram_a10 = bus.ppu_addr[10];
    assign bus.ciram_ce  = !bus.ppu_addr[13];

    /*always_ff @(posedge bus.m2) begin
        if (bus.cpu_rw) begin
            if (bus.cpu_addr == 'hFFFC) begin
                bus.cpu_data_out <= 'hFC;
            end else if (bus.cpu_addr == 'hFFFD) begin
                bus.cpu_data_out <= 'hFF;
            end
        end
    end*/
endmodule
