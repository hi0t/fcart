`timescale 1us / 1ns

module spi_tb;
    bit [7:0][7:0] sample;

    initial begin
        sample = {$urandom(), $urandom()};
        $display("Sample: %h", sample);

        $dumpfile("spi.vcd");
        $dumpvars(0, spi_tb);
    end

    logic spi_clk = 0;
    logic clk = 0;
    localparam CYC = 0.5;
    always #(CYC / 2) clk <= !clk;

    logic spi_cs = 1;
    logic spi_mosi;
    logic spi_miso;

    spi_bus bus ();

    spi spi (
        .clk(clk),
        .spi_clk(spi_clk),
        .spi_cs(spi_cs),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .bus(bus)
    );

    task slave;
        @(posedge clk iff bus.read_valid);
        assert (bus.data_read == 8'h53)
        else $fatal(1, "invalid cmd: %0h", bus.data_read);

        foreach (sample[i]) begin
            @(posedge clk iff bus.read_valid);
            assert (bus.data_read == sample[i])
            else $fatal(1, "invalid slave data: expected %0h, got %0h", sample[i], bus.data_read);
        end

        foreach (sample[i]) begin
            bus.data_write = sample[i];
            @(posedge clk iff bus.can_write);
        end
    endtask

    task send_byte(input [7:0] data);
        foreach (data[i]) begin
            spi_clk  = 0;
            spi_mosi = data[i];
            #(CYC / 2);
            spi_clk = 1;
            #(CYC / 2);
        end
        spi_clk = 0;
    endtask

    task recv_byte(output [7:0] data);
        foreach (data[i]) begin
            spi_clk = 0;
            data[i] = spi_miso;
            #(CYC / 2);
            spi_clk = 1;
            #(CYC / 2);
        end
        spi_clk = 0;
    endtask

    byte unsigned out;
    initial begin
        @(posedge clk);
        fork
            slave();
        join_none

        spi_cs = 0;

        send_byte(8'h53);
        foreach (sample[i]) send_byte(sample[i]);

        @(posedge clk);
        @(posedge clk);

        foreach (sample[i]) begin
            recv_byte(out);
            assert (out == sample[i])
            else $fatal(1, "invalid master data: expected %0h, got %0h", sample[i], out);
        end

        wait fork;
        spi_cs = 1;
        @(posedge clk);
        @(posedge clk);
        $finish;
    end
endmodule
