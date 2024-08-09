`timescale 1ns / 1ps

module sdram_tb;
    initial begin
        $dumpfile("sdram.vcd");
        $dumpvars(0, sdram_tb);
        $dumpvars(0, bus0);
        $dumpvars(0, bus1);
        $dumpvars(0, bus2);
        $dumpoff;
    end

    // 133.33333 MHz
    localparam CYC = 7.5;
    logic clk = 0;
    always #(CYC / 2) clk <= !clk;

    sdram_bus #(.ADDR_BITS(25)) bus0 (clk);
    sdram_bus #(.ADDR_BITS(25)) bus1 (clk);
    sdram_bus #(
        .ADDR_BITS(25),
        .WIDE(1)
    ) bus2 (
        clk
    );

    wire  [15:0] sdram_dq;
    wire  [12:0] sdram_addr;
    wire  [ 1:0] sdram_bank;
    wire         sdram_cke;
    wire  [ 3:0] sdram_command;
    wire  [ 1:0] sdram_dqm;
    logic        init;

    W9825G6KH sdram_model (
        .Dq   (sdram_dq),
        .Addr (sdram_addr),
        .Bs   (sdram_bank),
        .Clk  (clk),
        .Cke  (sdram_cke),
        .Cs_n (sdram_command[3]),
        .Ras_n(sdram_command[2]),
        .Cas_n(sdram_command[1]),
        .We_n (sdram_command[0]),
        .Dqm  (sdram_dqm)
    );

    sdram #(
        .ADDR_BITS(13),
        .COLUMN_BITS(9),
        .REFRESH_INTERVAL(1040)
    ) ram (
        .clk(clk),
        .ch0(bus0),
        .ch1(bus1),
        .ch2(bus2),
        .init(init),
        .cke(sdram_cke),
        .cs(sdram_command[3]),
        .address(sdram_addr),
        .bank(sdram_bank),
        .dq(sdram_dq),
        .ras(sdram_command[2]),
        .cas(sdram_command[1]),
        .we(sdram_command[0]),
        .dqm(sdram_dqm)
    );

    initial begin
        bus0.read = 0;
        bus0.write = 0;
        bus0.refresh = 0;
        bus1.read = 0;
        bus1.write = 0;
        bus1.refresh = 0;
        bus2.read = 0;
        bus2.write = 0;
        bus2.refresh = 0;
        init = 1;
        // Waiting for sdram to initialize
        #200_000;
        $dumpon;
        #500;

        // parallel write
        bus0.write = 1;
        bus1.write = 1;
        bus0.address = 'h00;
        bus1.address = 'h01;
        bus0.data_write = 'hF7;
        bus1.data_write = 'hF8;
        #(CYC * (ram.WRITE_PERIOD + 1)) bus0.write = 0;
        #(CYC * (ram.WRITE_PERIOD + 1)) bus1.write = 0;

        // parallel read
        bus0.read = 1;
        bus1.read = 1;
        bus0.address = 'h00;
        bus1.address = 'h01;
        #(CYC * 3);
        #(CYC * (ram.READ_PERIOD + 1)) bus0.read = 0;
        assert (bus0.data_read == 'hF7)
        else $fatal(1, "F7 != %0h", bus0.data_read);
        #(CYC * (ram.READ_PERIOD + 1)) bus1.read = 0;
        assert (bus1.data_read == 'hF8)
        else $fatal(1, "F8 != %0h", bus1.data_read);

        // write to the last bank
        bus0.write = 1;
        bus1.write = 1;
        bus0.address = 'b11_111111111_00000000000000;
        bus1.address = 'b11_111111111_00000000000001;
        bus0.data_write = 'hF9;
        bus1.data_write = 'hFA;
        #(CYC * 3);
        #(CYC * (ram.WRITE_PERIOD + 1)) bus0.write = 0;
        #(CYC * (ram.WRITE_PERIOD + 1)) bus1.write = 0;

        #(CYC * ram.REFRESH_INTERVAL / 2)

        // read with refresh
        bus0.read = 1;
        bus0.refresh = 1;
        bus0.address = 'b11_111111111_00000000000000;
        #(CYC * 3);
        #(CYC * (ram.READ_PERIOD + 1) * 2) bus0.read = 0;
        assert (bus0.data_read == 'hF9)
        else $fatal(1, "F9 != %0h", bus0.data_read);

        // 16bit channel
        bus2.read = 1;
        bus2.address = 'b11_111111111_0000000000000;
        #(CYC * 7);
        #(CYC * (ram.READ_PERIOD + 1)) bus2.read = 0;
        assert (bus2.data_read == 'hFAF9)
        else $fatal(1, "FAF9 != %0h", bus2.data_read);

        #(CYC * 1000) $finish;
    end
endmodule
