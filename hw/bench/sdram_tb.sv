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

    logic        read_cmd;
    logic        write_cmd;
    logic [21:0] address;
    logic [15:0] read_data;
    logic [15:0] write_data;

    wire  [15:0] sdram_dq;
    wire  [11:0] sdram_addr;
    wire  [ 1:0] sdram_bank;
    wire         sdram_cke;
    wire  [ 3:0] sdram_commond;
    wire  [ 1:0] sdram_dqm;

    mt48lc4m16a2 sdram_model (
        .Dq   (sdram_dq),
        .Addr (sdram_addr),
        .Ba   (sdram_bank),
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
        .INITIAL_PAUSE_US(100),
        .REFRESH_TIME_NS(66)
    ) ram (
        .clk(clk),

        .read_req(read_cmd),
        .write_req(write_cmd),
        .address_req(address),
        .data_in(write_data),
        .data_out(read_data),
        .busy(),

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

    initial begin
        read_cmd  = 0;
        write_cmd = 0;

        // Waiting for sdram to initialize
        #100_000 $dumpon;
        #500

        // regular write
        write_cmd = 1;
        address = 'h00;
        write_data = 'h0FF7;
        #(CYC) write_cmd = 0;
        #(CYC * 4)

        // write to the last bank
        write_cmd = 1;
        address = 'b1110000000000000000000;
        write_data = 'h1FF7;
        #(CYC) write_cmd = 0;
        #(CYC * 4)

        // regular read
        read_cmd = 1;
        address = 'h00;
        #(CYC) read_cmd = 0;
        #(CYC * 5)
        assert (read_data == 'h0FF7)
        else $fatal(1, "0FF7 != %0h", read_data);

        // read from the next bank
        read_cmd = 1;
        address  = 'b1110000000000000000000;
        #(CYC) read_cmd = 0;
        #(CYC * 5)
        assert (read_data == 'h1FF7)
        else $fatal(1, "1FF7 != %0h", read_data);

        #(CYC * 1000)
        // read after auto-refresh
        read_cmd = 1;
        address = 'b1110000000000000000000;
        #(CYC) read_cmd = 0;
        #(CYC * 5)
        assert (read_data == 'h1FF7)
        else $fatal(1, "1FF7 != %0h", read_data);

        #(CYC * 1000) $finish;
    end
endmodule
