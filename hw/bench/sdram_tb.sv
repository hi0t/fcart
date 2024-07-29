`timescale 1ns / 1ps

module sdram_tb;
    initial begin
        $dumpfile("sdram.vcd");
        $dumpvars(0, sdram_tb);
        $dumpoff;
    end

    localparam CYC = 20;
    logic clk = 0;
    always #(CYC / 2) clk <= !clk;

    sdram_bus #(24, 16) bus16 ();
    sdram_bus #(25, 8) bus8_0 ();
    sdram_bus #(25, 8) bus8_1 ();

    wire [15:0] sdram_dq;
    wire [12:0] sdram_addr;
    wire [ 1:0] sdram_bank;
    wire        sdram_cke;
    wire [ 3:0] sdram_commond;
    wire [ 1:0] sdram_dqm;

    W9825G6KH sdram_model (
        .Dq   (sdram_dq),
        .Addr (sdram_addr),
        .Bs   (sdram_bank),
        .Clk  (clk),
        .Cke  (sdram_cke),
        .Cs_n (sdram_commond[3]),
        .Ras_n(sdram_commond[2]),
        .Cas_n(sdram_commond[1]),
        .We_n (sdram_commond[0]),
        .Dqm  (sdram_dqm)
    );

    sdram #(
        .CLK_FREQ(50_000_000),
        .ADDR_BITS(13),
        .COLUMN_BITS(9),
        .REFRESH_INTERVAL_US(7.81)
    ) ram (
        .clk(clk),
        .ch_16bit(bus16),
        .ch0_8bit(bus8_0),
        .ch1_8bit(bus8_1),

        .cke(sdram_cke),
        .cs(sdram_commond[3]),
        .address(sdram_addr),
        .bank(sdram_bank),
        .dq(sdram_dq),
        .ras(sdram_commond[2]),
        .cas(sdram_commond[1]),
        .we(sdram_commond[0]),
        .dqm(sdram_dqm)
    );

    task automatic test_ch16(int delay, ref logic read, write, ref logic [23:0] address,
                             ref logic [15:0] data_write, ref logic [15:0] data_read);
        // regular write
        write = 1;
        address = 'h00;
        data_write = 'h0FF7;
        #(CYC * delay) write = 0;
        $display("start 16 with delay %d", delay);
        #(CYC * 7);
        // write to the last bank
        write = 1;
        address = 'b11_111111111_0000000000000;
        data_write = 'h1FF7;
        #(CYC) write = 0;
        #(CYC * 7);
        // test of writing two 8-bit value
        write = 1;
        address = 'h7FFC / 2;
        data_write = 'h8000;
        #(CYC * delay) write = 0;
        #(CYC * 7);
        // regular read
        read = 1;
        address = 'h00;
        #(CYC) read = 0;
        #(CYC * 8);
        assert (data_read == 'h0FF7)
        else $fatal(1, "0FF7 != %0h", data_read);
        #(CYC * 500);
        // read after auto-refresh
        read = 1;
        address = 'b11_111111111_0000000000000;
        #(CYC) read = 0;
        #(CYC * 8);
        assert (data_read == 'h1FF7)
        else $fatal(1, "1FF7 != %0h", data_read);
    endtask

    task automatic test_ch8(int delay, bit [7:0] diff, ref logic read, write,
                            ref logic [24:0] address, ref logic [7:0] data_write,
                            ref logic [7:0] data_read);
        // regular write
        write = 1;
        address = 'h77 + $bits(address)'(diff);
        data_write = 'h77 + diff;
        #(CYC * delay) write = 0;
        $display("start 8 with delay %d", delay);
        #(CYC * 7);
        read = 1;
        #(CYC) read = 0;
        #(CYC * 8);
        assert (data_read == data_write)
        else $fatal(1, "%0h != %0h", data_read, data_write);
    endtask

    initial begin
        bus16.read   = 0;
        bus16.write  = 0;
        bus8_0.read  = 0;
        bus8_0.write = 0;
        bus8_1.read  = 0;
        bus8_1.write = 0;

        // Waiting for sdram to initialize
        #200_000 $dumpon;
        #500;

        fork
            test_ch16(30, bus16.read, bus16.write, bus16.address, bus16.data_write,
                      bus16.data_read);
            test_ch8(10, 0, bus8_0.read, bus8_0.write, bus8_0.address, bus8_0.data_write,
                     bus8_0.data_read);
            test_ch8(20, 1, bus8_1.read, bus8_1.write, bus8_1.address, bus8_1.data_write,
                     bus8_1.data_read);
        join

        #(CYC * 1000);

        // test reading a previously written 16-bit value
        bus8_0.read = 1;
        bus8_0.address = 'h7FFC;
        #(CYC) bus8_0.read = 0;
        #(CYC * 8);
        assert (bus8_0.data_read == 'h00)
        else $fatal(1, "00 != %0h", bus8_0.data_read);

        bus8_0.read = 1;
        bus8_0.address = 'h7FFD;
        #(CYC) bus8_0.read = 0;
        #(CYC * 8);
        assert (bus8_0.data_read == 'h80)
        else $fatal(1, "80 != %0h", bus8_0.data_read);

        $finish;
    end
endmodule
