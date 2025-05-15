`timescale 1us / 1ns

module qspi_tb;
    initial begin
        $dumpfile("qspi.vcd");
        $dumpvars(0, qspi_tb);
    end

    logic qspi_clk;
    logic clk = 0;
    localparam CYC = 0.5;
    always #(CYC / 2) clk <= !clk;

    logic reset;
    logic [3:0] io_buf;
    logic master_we;
    logic [7:0] req_dataq[$], resp_dataq[$], tx_byte, rx_byte;
    logic qspi_ncs;
    wire [3:0] qspi_io;

    bidir_bus bus ();

    assign qspi_io = master_we ? io_buf : 'z;

    qspi qspi (
        .clk(clk),
        .reset(reset),
        .bus(bus.provider),
        .qspi_clk(qspi_clk),
        .qspi_ncs(qspi_ncs),
        .qspi_io(qspi_io)
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
        #(CYC / 2) qspi_clk = 1;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task mcu;
        qspi_ncs  = 1;
        master_we = 1;

        #(CYC);

        qspi_ncs = 0;
        #(CYC / 4);
        send_byte(8'h00);  // Reset FIFO
        #(CYC / 4);
        qspi_ncs = 1;

        #(CYC);

        qspi_ncs = 0;
        #(CYC / 4);
        send_byte(8'h01);  // Send command
        #(CYC / 4);
        qspi_ncs = 1;

        qspi_ncs = 0;
        #(CYC / 4);
        for (int i = 0; i < 10; i++) begin
            tx_byte = 8'($urandom);
            send_byte(tx_byte);  // Send some data
            req_dataq.push_back(tx_byte);
        end

        master_we = 0;
        repeat (4) dummy_cycle;

        for (int i = 0; i < 10; i++) begin
            recv_byte(rx_byte);  // Receive some data
            tx_byte = resp_dataq.pop_front();
            assert (rx_byte == tx_byte)
            else
                $fatal(
                    1, "Invalid data received from device: expected %0h, got %0h", tx_byte, rx_byte
                );
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

        @(posedge clk iff !bus.rd_empty);
        bus.rd_en = 1;
        assert (bus.rd_data == 8'h01)
        else $fatal(1, "Invalid received from mcu: %0h", bus.rd_data);
        @(posedge clk) bus.rd_en = 0;

        for (int i = 0; i < 10; i++) begin
            @(posedge clk iff !bus.rd_empty);
            bus.rd_en = 1;
            rx_byte   = req_dataq.pop_front();
            assert (bus.rd_data == rx_byte)
            else
                $fatal(
                    1, "Invalid data received from mcu: expected %0h, got %0h", rx_byte, bus.rd_data
                );
            @(posedge clk) bus.rd_en = 0;
        end

        for (int i = 0; i < 10; i++) begin
            @(posedge clk iff !bus.wr_full);
            bus.wr_en   = 1;
            bus.wr_data = 8'($urandom);
            resp_dataq.push_back(bus.wr_data);
            @(posedge clk) bus.wr_en = 0;
        end

        wait fork;
        repeat (2) @(posedge clk);
        $finish;
    end
endmodule
