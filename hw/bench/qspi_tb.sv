`timescale 1us / 1ns

module qspi_tb;
    bit [7:0][7:0] sample;

    initial begin
        sample = {$urandom(), $urandom()};
        $display("Sample: %h", sample);

        $dumpfile("qspi.vcd");
        $dumpvars(0, qspi_tb);
    end

    logic qspi_clk = 0;
    always #(0.5) qspi_clk <= !qspi_clk;

    logic qspi_ncs = 1;
    wire [3:0] qspi_io;

    qspi_bus bus ();
    logic master_we;
    logic [3:0] io_buf;

    assign qspi_io = master_we ? io_buf : 'z;

    qspi qspi (
        .qspi_clk(qspi_clk),
        .qspi_ncs(qspi_ncs),
        .qspi_io(qspi_io),
        .bus(bus)
    );

    task slave;
        @(posedge qspi_clk iff bus.cmd_ready);
        assert (bus.cmd == 8'h9F)
        else $fatal(1, "invalid cmd: %0h", bus.cmd);

        foreach (sample[i]) begin
            @(posedge qspi_clk iff bus.data_ready);
            assert (bus.data_read == sample[i])
            else $fatal(1, "invalid slave data: expected %0h, got %0h", sample[i], bus.data_read);
        end

        bus.we = 1;
        foreach (sample[i]) begin
            @(posedge qspi_clk iff bus.can_write);
            bus.data_write = sample[i];
        end
        bus.we = 0;
    endtask

    task send_byte(input [7:0] data);
        io_buf = data[7:4];
        @(posedge qspi_clk);
        io_buf = data[3:0];
        @(posedge qspi_clk);
    endtask

    task recv_byte(output [7:0] data);
        @(posedge qspi_clk);
        data[7:4] = qspi_io;
        @(posedge qspi_clk);
        data[3:0] = qspi_io;
    endtask

    byte unsigned out;
    initial begin
        @(posedge qspi_clk);
        fork
            slave();
        join_none

        qspi_ncs  = 0;
        master_we = 1;

        send_byte(8'h9F);
        foreach (sample[i]) send_byte(sample[i]);

        master_we = 0;
        @(posedge qspi_clk);  // io switch
        @(posedge qspi_clk);

        foreach (sample[i]) begin
            recv_byte(out);
            assert (out == sample[i])
            else $fatal(1, "invalid master data: expected %0h, got %0h", sample[i], out);
        end

        qspi_ncs = 1;
        @(posedge qspi_clk);
        $finish;
    end
endmodule
