`timescale 1us / 1ns

module qspi_tb;
    bit [7:0][7:0] sample;

    initial begin
        sample = {$urandom(), $urandom()};
        $display("Sample: %h", sample);

        $dumpfile("qspi.vcd");
        $dumpvars(0, qspi_tb);
    end

    logic clk = 0, qspi_clk = 0;
    always #(0.25) clk <= !clk;
    always #(0.5) qspi_clk <= !qspi_clk;

    logic qspi_ncs = 1;
    wire [3:0] qspi_io;
    logic [7:0] cmd;
    logic cmd_ready;
    logic [7:0] data_read;
    logic [7:0] data_write;
    logic data_ready;
    logic we = 0;
    logic [3:0] io_buf;

    assign qspi_io = we ? 'z : io_buf;

    qspi qspi (
        .qspi_clk(qspi_clk),
        .qspi_ncs(qspi_ncs),
        .qspi_io(qspi_io),
        .clk(clk),
        .cmd(cmd),
        .cmd_ready(cmd_ready),
        .data_read(data_read),
        .data_write(data_write),
        .data_ready(data_ready),
        .we(we)
    );

    task slave;
        @(posedge clk iff cmd_ready);
        assert (cmd == 8'h9F)
        else $fatal(1, "invalid cmd: %0h", cmd);

        foreach (sample[i]) begin
            @(posedge clk iff data_ready);
            assert (data_read == sample[i])
            else $fatal(1, "invalid slave data: expected %0h, got %0h", sample[i], data_read);
        end

        we = 1;
        foreach (sample[i]) begin
            data_write = sample[i];
            @(posedge clk iff data_ready);
        end
        we = 0;
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

        qspi_ncs = 0;

        send_byte(8'h9F);
        foreach (sample[i]) send_byte(sample[i]);

        @(posedge qspi_clk);  // Wait for the last byte to be sent

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
