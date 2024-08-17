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

    sdram_bus #(.ADDR_BITS(24)) bus0 ();
    sdram_bus #(.ADDR_BITS(24)) bus1 ();
    sdram_bus #(.ADDR_BITS(24)) bus2 ();

    wire  [15:0] sdram_dq;
    wire  [12:0] sdram_addr;
    wire  [ 1:0] sdram_bank;
    wire         sdram_cke;
    wire  [ 3:0] sdram_command;
    wire  [ 1:0] sdram_dqm;
    logic        init;
    logic        refresh;

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
        .refresh(refresh),

        .SDRAM_CKE (sdram_cke),
        .SDRAM_CS  (sdram_command[3]),
        .SDRAM_ADDR(sdram_addr),
        .SDRAM_BA  (sdram_bank),
        .SDRAM_DQ  (sdram_dq),
        .SDRAM_RAS (sdram_command[2]),
        .SDRAM_CAS (sdram_command[1]),
        .SDRAM_WE  (sdram_command[0]),
        .SDRAM_DQM (sdram_dqm)
    );

    initial begin
        init = 1;
        // Waiting for sdram to initialize
        #200_000;
        $dumpon;
        #500;

        // parallel write
        bus0.req = ~bus0.req;
        bus1.req = ~bus1.req;
        bus0.we = 1;
        bus1.we = 1;
        bus0.address = 'h00;
        bus1.address = 'h01;
        bus0.data_write = 'hF7F8;
        bus1.data_write = 'hA7F8;
        #(CYC * (ram.WRITE_PERIOD + 1));
        #(CYC * (ram.WRITE_PERIOD + 1));
        #(CYC)

        // parallel read
        bus0.req = ~bus0.req;
        bus1.req = ~bus1.req;
        bus0.we = 0;
        bus1.we = 0;
        bus0.address = 'h00;
        bus1.address = 'h01;
        wait (bus0.req == bus0.ack);
        assert (bus0.data_read == 'hF7F8)
        else $fatal(1, "hF7F8 != %0h", bus0.data_read);
        wait (bus1.req == bus1.ack);
        assert (bus1.data_read == 'hA7F8)
        else $fatal(1, "hA7F8 != %0h", bus1.data_read);
        #(CYC * ram.READ_PERIOD)

        // write to the last bank
        bus0.req = ~bus0.req;
        bus1.req = ~bus1.req;
        bus0.we = 1;
        bus1.we = 1;
        bus0.address = 'b11_111111111_0000000000000;
        bus1.address = 'b11_111111111_0000000000001;
        bus0.data_write = 'hF7F9;
        bus1.data_write = 'hA7FA;
        #(CYC * (ram.WRITE_PERIOD + 1));
        #(CYC * (ram.WRITE_PERIOD + 1));

        refresh = 1;
        #(CYC) refresh = 0;

        // Read from the third channel
        bus2.req = ~bus2.req;
        bus2.we = 0;
        bus2.address = 'b11_111111111_0000000000001;
        wait (bus2.req == bus2.ack);
        assert (bus2.data_read == 'hA7FA)
        else $fatal(1, "hA7FA != %0h", bus2.data_read);

        #(CYC * 1000) $finish;
    end
endmodule
