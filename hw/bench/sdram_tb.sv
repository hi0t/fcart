`timescale 1ns / 1ps

module sdram_tb;
    initial begin
        $dumpfile("sdram.vcd");
    end

    logic        clk = 0;
    wire  [15:0] sdram_dq;
    wire  [12:0] sdram_addr;
    wire  [ 1:0] sdram_bank;
    wire  [ 3:0] sdram_command;
    wire  [ 1:0] sdram_dqm;
    logic        init;
    logic        refresh;

    // 133.33333 MHz
    always #(7.5 / 2) clk <= !clk;

    sdram_bus #(.ADDR_BITS(24)) bus0 ();
    sdram_bus #(.ADDR_BITS(24)) bus1 ();

    W9825G6KH sdram_model (
        .Dq   (sdram_dq),
        .Addr (sdram_addr),
        .Bs   (sdram_bank),
        .Clk  (clk),
        .Cke  (1'b1),
        .Cs_n (sdram_command[3]),
        .Ras_n(sdram_command[2]),
        .Cas_n(sdram_command[1]),
        .We_n (sdram_command[0]),
        .Dqm  (sdram_dqm)
    );

    sdram #(
        .ROW_BITS(13),
        .COL_BITS(9)
    ) ram (
        .ch0(bus0),
        .ch1(bus1),
        .init(init),
        .refresh(refresh),

        .sdram_clk (clk),
        .sdram_cs  (sdram_command[3]),
        .sdram_addr(sdram_addr),
        .sdram_ba  (sdram_bank),
        .sdram_dq  (sdram_dq),
        .sdram_ras (sdram_command[2]),
        .sdram_cas (sdram_command[1]),
        .sdram_we  (sdram_command[0]),
        .sdram_dqm (sdram_dqm)
    );

    initial begin
        init = 1;

        // skip powerup
        wait (ram.state == ram.STATE_CONFIGURE);
        $dumpvars(0, sdram_tb);

        wait (ram.state == ram.STATE_IDLE);

        // Parallel write
        bus0.req = ~bus0.req;
        bus1.req = ~bus1.req;
        bus0.we = 1;
        bus1.we = 1;
        bus0.address = 'h00;
        bus1.address = 'h01;
        bus0.data_write = 'hF7F8;
        bus1.data_write = 'hA7F8;
        @(posedge clk iff bus0.req == bus0.ack);
        @(posedge clk iff bus1.req == bus1.ack);

        // Parallel read
        bus0.data_read = 'x;
        bus1.data_read = 'x;
        bus0.req = ~bus0.req;
        bus1.req = ~bus1.req;
        bus0.we = 0;
        bus1.we = 0;
        bus0.address = 'h00;
        bus1.address = 'h01;
        @(posedge clk iff bus0.req == bus0.ack);
        assert (bus0.data_read == 'hF7F8)
        else $fatal(1, "hF7F8 != %0h", bus0.data_read);
        @(posedge clk iff bus1.req == bus1.ack);
        assert (bus1.data_read == 'hA7F8)
        else $fatal(1, "hA7F8 != %0h", bus1.data_read);

        refresh = 1;
        wait (ram.state == ram.STATE_REFRESH);

        // refresh -> write
        bus0.req = ~bus0.req;
        bus0.we = 1;
        bus0.address = '1;  // max address
        bus0.data_write = 'hF7F8;
        @(posedge clk iff bus0.req == bus0.ack);

        wait (ram.timer == ram.REFRESH_INTERVAL / 2);

        // read -> refresh
        bus0.data_read = 'x;
        bus0.req = ~bus0.req;
        bus0.we = 0;
        bus0.address = '1;
        @(posedge clk iff bus0.req == bus0.ack);
        assert (bus0.data_read == 'hF7F8)
        else $fatal(1, "hF7F8 != %0h", bus0.data_read);

        wait (ram.state == ram.STATE_REFRESH);
        wait (ram.state == ram.STATE_IDLE);
        $finish;
    end
endmodule
