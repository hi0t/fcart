`timescale 1us / 1ns

module qspi_tb;
    initial begin
        $dumpfile("qspi.vcd");
        $dumpvars(0, qspi_tb);
    end

    logic qspi_clk;
    logic clk;
    localparam CYC = 0.5;
    always #(CYC / 8) clk <= !clk;

    logic reset;
    logic [3:0] io_buf;
    logic master_we;
    logic [7:0] req_dataq[$], resp_dataq[$], tx_byte, rx_byte;
    logic qspi_ncs;
    wire [3:0] qspi_io;

    logic [7:0] rd_data;
    logic rd_valid;
    logic [7:0] wr_data;
    logic wr_valid;
    logic start;

    assign qspi_io = master_we ? io_buf : 'z;

    qspi qspi (
        .clk(clk),
        .async_reset(reset),

        .qspi_clk(qspi_clk),
        .qspi_ncs(qspi_ncs),
        .qspi_io (qspi_io),

        .rd_data(rd_data),
        .rd_valid(rd_valid),
        .wr_data(wr_data),
        .wr_valid(wr_valid),
        .start(start)
    );

    task send_byte(input [7:0] data);
        qspi_clk = 0;
        io_buf   = data[7:4];
        #(CYC / 2) qspi_clk = 1;
        #(CYC / 2) qspi_clk = 0;
        io_buf = data[3:0];
        #(CYC / 2) qspi_clk = 1;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task recv_byte(output [7:0] data);
        qspi_clk = 0;
        #(CYC / 2) qspi_clk = 1;
        data[7:4] = qspi_io;
        #(CYC / 2) qspi_clk = 0;
        #(CYC / 2) qspi_clk = 1;
        data[3:0] = qspi_io;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task dummy_cycle;
        qspi_clk = 0;
        #(CYC / 2) qspi_clk = 1;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task mcu;
        clk = 0;
        qspi_ncs = 1;
        master_we = 1;

        #(CYC);  // Waiting reset device

        qspi_ncs = 0;
        #(CYC / 4);
        send_byte(8'h02);  // Send read command

        for (int i = 0; i < 3; i++) begin
            tx_byte = 8'($urandom);
            req_dataq.push_back(tx_byte);
            send_byte(tx_byte);  // Send address
        end

        master_we = 0;
        repeat (2) dummy_cycle;

        for (int i = 0; i < 10; i++) begin
            recv_byte(rx_byte);  // Receive some data
            tx_byte = resp_dataq.pop_front();
            assert (rx_byte == tx_byte)
            else $fatal(1, "Invalid data received from device: expected %0h, got %0h", tx_byte, rx_byte);
        end

        #(CYC / 4);
        qspi_ncs = 1;

        #(CYC * 2);

        master_we = 1;
        qspi_ncs  = 0;
        #(CYC / 4);
        send_byte(8'h03);  // Send write command

        for (int i = 0; i < 20; i++) begin
            tx_byte = 8'($urandom);
            req_dataq.push_back(tx_byte);
            send_byte(tx_byte);  // Send address and some data
        end

        #(CYC / 4);
        qspi_ncs = 1;
    endtask

    initial begin
        fork
            mcu();
        join_none

        reset = 1;
        @(posedge clk) reset = 0;

        @(posedge clk iff start);

        @(posedge clk iff rd_valid);
        assert (rd_data == 8'h02)
        else $fatal(1, "Invalid received from mcu: %0h", rd_data);

        for (int i = 0; i < 3; i++) begin
            @(posedge clk iff rd_valid);
            rx_byte = req_dataq.pop_front();
            assert (rd_data == rx_byte)
            else $fatal(1, "Invalid data received from mcu: expected %0h, got %0h", rx_byte, rd_data);
        end

        for (int i = 0; i < 10; i++) begin
            @(posedge clk iff wr_valid);
            wr_data = 8'($urandom);
            resp_dataq.push_back(wr_data);
        end

        @(posedge clk iff start);

        @(posedge clk iff rd_valid);
        assert (rd_data == 8'h03)
        else $fatal(1, "Invalid received from mcu: %0h", rd_data);

        for (int i = 0; i < 20; i++) begin
            @(posedge clk iff rd_valid);
            rx_byte = req_dataq.pop_front();
            assert (rd_data == rx_byte)
            else $fatal(1, "Invalid data received from mcu: expected %0h, got %0h", rx_byte, rd_data);
        end

        wait fork;
        repeat (2) @(posedge clk);
        $finish;
    end
endmodule
