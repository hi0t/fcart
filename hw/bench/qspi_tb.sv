`timescale 1us / 1ns

module qspi_tb;
    initial begin
        $dumpfile("qspi.vcd");
        $dumpvars(0, qspi_tb);
        #10s $finish;
    end

    logic qspi_clk;
    logic clk;
    localparam CYC = 8;
    always #(CYC / 8) clk <= !clk;

    logic reset;
    logic [3:0] io_buf;
    logic master_we;
    logic [7:0] req_dataq[$], resp_dataq[$], tx_byte, rx_byte;
    logic [23:0] address;
    logic qspi_ncs;
    wire [3:0] qspi_io;

    logic [15:0] rd_data;
    logic rd_valid;
    logic rd_ready;
    logic [15:0] wr_data;
    logic wr_valid;
    logic wr_ready;
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
        .rd_ready(rd_ready),
        .wr_data(wr_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
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

        #(CYC);

        qspi_ncs = 0;
        send_byte('h02);  // Send read command

        for (int i = 0; i < 3; i++) begin
            tx_byte = 8'($urandom);
            req_dataq.push_back(tx_byte);
            send_byte(tx_byte);  // Send address
        end

        master_we = 0;
        repeat (8) dummy_cycle;

        for (int i = 0; i < 20; i++) begin
            recv_byte(rx_byte);  // Receive some data
            tx_byte = resp_dataq.pop_front();
            assert (rx_byte == tx_byte)
            else $fatal(1, "Invalid data received from device: expected %0h, got %0h", tx_byte, rx_byte);
        end

        qspi_ncs = 1;

        #(CYC * 2);

        master_we = 1;
        qspi_ncs  = 0;
        send_byte('h03);  // Send write command

        for (int i = 0; i < 23; i++) begin
            tx_byte = 8'($urandom);
            req_dataq.push_back(tx_byte);
            send_byte(tx_byte);  // Send address and some data
        end

        qspi_ncs = 1;
    endtask

    task automatic check_24bit(ref logic [7:0] q[$], input logic [23:0] expected);
        logic [23:0] pop_24bit;
        if (q.size() < 3) begin
            $fatal(1, "Not enough data in queue to pop 24 bits");
        end
        pop_24bit = {>>{q[0:2]}};
        q = q[3:$];

        assert (pop_24bit === expected)
        else $fatal(1, "Invalid data received from mcu: expected %0h, got %0h", expected, pop_24bit);
    endtask

    task automatic check_16bit(ref logic [7:0] q[$], input logic [15:0] expected);
        logic [15:0] pop_16bit;
        if (q.size() < 2) begin
            $fatal(1, "Not enough data in queue to pop 16 bits");
        end
        pop_16bit = {q[0], q[1]};
        q = q[2:$];

        assert (pop_16bit === expected)
        else $fatal(1, "Invalid data received from mcu: expected %0h, got %0h", expected, pop_16bit);
    endtask

    initial begin
        fork
            mcu();
        join_none

        reset = 1;
        @(posedge clk) reset = 0;

        @(posedge clk iff start);

        @(posedge clk iff rd_valid);
        rd_ready = 1;
        assert (rd_data[15:8] == 'h02)
        else $fatal(1, "Invalid command received from mcu: %0h", rd_data[15:8]);
        address[23:16] = rd_data[7:0];
        @(posedge clk) rd_ready = 0;

        @(posedge clk iff rd_valid);
        rd_ready = 1;
        address[15:0] = rd_data;
        check_24bit(req_dataq, address);
        @(posedge clk) rd_ready = 0;

        for (int i = 0; i < 10; i++) begin
            @(posedge clk iff wr_valid);
            wr_ready = 1;
            wr_data  = 16'($urandom);
            resp_dataq.push_back(wr_data[15:8]);
            resp_dataq.push_back(wr_data[7:0]);
            @(posedge clk) wr_ready = 0;
        end

        @(posedge clk iff start);

        @(posedge clk iff rd_valid);
        rd_ready = 1;
        assert (rd_data[15:8] == 8'h03)
        else $fatal(1, "Invalid command received from mcu: %0h", rd_data[15:8]);
        address[23:16] = rd_data[7:0];
        @(posedge clk) rd_ready = 0;

        @(posedge clk iff rd_valid);
        rd_ready = 1;
        address[15:0] = rd_data;
        check_24bit(req_dataq, address);
        @(posedge clk) rd_ready = 0;

        for (int i = 0; i < 10; i++) begin
            @(posedge clk iff rd_valid);
            rd_ready = 1;
            check_16bit(req_dataq, rd_data);
            @(posedge clk) rd_ready = 0;
        end

        wait fork;
        repeat (2) @(posedge clk);
        $finish;
    end
endmodule
