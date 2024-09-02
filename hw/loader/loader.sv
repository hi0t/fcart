module loader;
    logic tck, tdi, tdo, vs_sdr;
    logic sdr;
    logic spi_clk, spi_cs, spi_si, spi_so;

    sld_virtual_jtag #(
        .sld_auto_instance_index("YES"),
        .sld_instance_index     (0),
        .sld_ir_width           (1)
    ) virtual_jtag (
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .virtual_state_sdr(vs_sdr)
    );

    altserial_flash_loader #(
        .INTENDED_DEVICE_FAMILY ("Cyclone 10 LP"),
        .ENABLE_QUAD_SPI_SUPPORT(0),
        .ENABLE_SHARED_ACCESS   ("ON"),
        .ENHANCED_MODE          (0),
        .NCSO_WIDTH             (1)
    ) serial_flash_loader (
        .dclkin(spi_clk),
        .scein(spi_cs),
        .sdoin(spi_si),
        .data0out(spi_so),
        .noe(1'b0),
        .asmi_access_granted(1'b1)
    );

    assign spi_cs = !sdr;
    assign spi_clk = sdr ? tck : 1'b0;
    assign spi_si = sdr ? tdi : 1'b0;
    assign tdo = sdr ? spi_so : tdi;

    always_ff @(negedge tck) sdr <= vs_sdr;
endmodule
