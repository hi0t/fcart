`timescale 1ns / 1ps

module api_tb;
    // Clock generation
    logic clk;
    logic qspi_clk;
    localparam CYC = 40;  // 25MHz QSPI clock period

    // System clock (100MHz)
    always #5 clk <= !clk;

    // Signals
    logic reset;
    logic fpga_irq;
    logic [31:0] wr_reg;
    logic [3:0] wr_reg_addr;
    logic wr_reg_changed;
    logic [31:0] ev_reg;

    // QSPI signals
    logic qspi_ncs;
    wire [3:0] qspi_io;
    logic [3:0] io_buf;
    logic master_we;

    // Internal QSPI signals
    logic [15:0] rd_data;
    logic rd_valid;
    logic rd_ready;
    logic [15:0] wr_data;
    logic wr_valid;
    logic wr_ready;
    logic start;
    logic ram_refresh;

    // SDRAM interface
    sdram_bus ram ();
    sdram_bus bus1 ();
    sdram_bus bus2 ();

    wire [15:0] sdram_dq;
    wire [12:0] sdram_addr;
    wire [ 1:0] sdram_bank;
    wire [ 3:0] sdram_command;
    wire [ 1:0] sdram_dqm;

    // Instantiation
    api uut (
        .clk(clk),
        .reset(reset),
        .fpga_irq(fpga_irq),
        .wr_reg(wr_reg),
        .wr_reg_addr(wr_reg_addr),
        .wr_reg_changed(wr_reg_changed),
        .ev_reg(ev_reg),
        .ram(ram.controller),
        .ram_refresh(ram_refresh),
        .rd_data(rd_data),
        .rd_valid(rd_valid),
        .rd_ready(rd_ready),
        .wr_data(wr_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .start(start)
    );

    qspi qspi_inst (
        .clk(clk),
        .async_reset(reset),
        .qspi_clk(qspi_clk),
        .qspi_ncs(qspi_ncs),
        .qspi_io(qspi_io),
        .rd_data(rd_data),
        .rd_valid(rd_valid),
        .rd_ready(rd_ready),
        .wr_data(wr_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .start(start)
    );

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
    ) sdram_inst (
        .clk(clk),
        .reset(reset),
        .ch0(ram.memory),
        .ch1(bus1.memory),
        .ch2(bus2.memory),
        .refresh(ram_refresh),

        .sdram_cs  (sdram_command[3]),
        .sdram_addr(sdram_addr),
        .sdram_ba  (sdram_bank),
        .sdram_dq  (sdram_dq),
        .sdram_ras (sdram_command[2]),
        .sdram_cas (sdram_command[1]),
        .sdram_we  (sdram_command[0]),
        .sdram_dqm (sdram_dqm)
    );

    assign qspi_io = master_we ? io_buf : 4'bz;

    // Drive unused buses
    initial begin
        bus1.req = 0;
        bus1.we = 0;
        bus1.wm = 0;
        bus1.address = 0;
        bus1.data_write = 0;
        bus2.req = 0;
        bus2.we = 0;
        bus2.wm = 0;
        bus2.address = 0;
        bus2.data_write = 0;
    end

    // Tasks
    task send_nibble(input [3:0] nibble);
        qspi_clk = 0;
        io_buf   = nibble;
        #(CYC / 2) qspi_clk = 1;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task send_byte(input [7:0] data);
        send_nibble(data[7:4]);
        send_nibble(data[3:0]);
    endtask

    task recv_nibble(output [3:0] nibble);
        qspi_clk = 0;
        #(CYC / 2) qspi_clk = 1;
        nibble = qspi_io;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task recv_byte(output [7:0] data);
        logic [3:0] high, low;
        recv_nibble(high);
        recv_nibble(low);
        data = {high, low};
    endtask

    task dummy_cycle;
        qspi_clk = 0;
        #(CYC / 2) qspi_clk = 1;
        #(CYC / 2) qspi_clk = 0;
    endtask

    task write_reg(input [23:0] addr, input [31:0] data);
        $display("Writing Register: Addr=%h, Data=%h", addr, data);
        qspi_ncs  = 0;
        master_we = 1;

        send_byte(8'h03);  // CMD_WRITE_REG
        send_byte(addr[23:16]);
        send_byte(addr[15:8]);
        send_byte(addr[7:0]);

        send_byte(data[7:0]);
        send_byte(data[15:8]);
        send_byte(data[23:16]);
        send_byte(data[31:24]);

        master_we = 0;
        qspi_ncs  = 1;
    endtask

    task read_reg(input [23:0] addr, output [31:0] data);
        logic [7:0] b0, b1, b2, b3;
        $display("Reading Register: Addr=%h", addr);
        qspi_ncs  = 0;
        master_we = 1;

        send_byte(8'h02);  // CMD_READ_REG
        send_byte(addr[23:16]);
        send_byte(addr[15:8]);
        send_byte(addr[7:0]);

        master_we = 0;
        repeat (4) dummy_cycle;

        // Let's try receiving immediately.
        recv_byte(b0);
        recv_byte(b1);
        recv_byte(b2);
        recv_byte(b3);

        data = {b3, b2, b1, b0};

        qspi_ncs = 1;
    endtask

    task write_mem(input [23:0] start_addr, input [15:0] data1, input [15:0] data2);
        $display("Writing Memory: Addr=%h, Data1=%h, Data2=%h", start_addr, data1, data2);
        qspi_ncs  = 0;
        master_we = 1;

        send_byte(8'h01);  // CMD_WRITE_MEM
        send_byte(start_addr[23:16]);
        send_byte(start_addr[15:8]);
        send_byte(start_addr[7:0]);

        // Data 1
        send_byte(data1[7:0]);
        send_byte(data1[15:8]);

        // Data 2
        send_byte(data2[7:0]);
        send_byte(data2[15:8]);

        master_we = 0;
        qspi_ncs  = 1;
    endtask

    task read_mem(input [23:0] start_addr, output [15:0] data1, output [15:0] data2);
        logic [7:0] b0, b1, b2, b3;
        $display("Reading Memory: Addr=%h", start_addr);
        qspi_ncs  = 0;
        master_we = 1;

        send_byte(8'h00);  // CMD_READ_MEM
        send_byte(start_addr[23:16]);
        send_byte(start_addr[15:8]);
        send_byte(start_addr[7:0]);

        master_we = 0;
        repeat (4) dummy_cycle;

        // Read Data 1
        recv_byte(b0);
        recv_byte(b1);
        data1 = {b1, b0};

        // Read Data 2
        recv_byte(b2);
        recv_byte(b3);
        data2 = {b3, b2};

        qspi_ncs = 1;
    endtask

    // Test Sequence
    initial begin
        $dumpfile("api_tb.vcd");
        $dumpvars(0, api_tb);

        // Initialize
        clk = 0;
        qspi_clk = 0;
        reset = 1;
        qspi_ncs = 1;
        master_we = 0;
        ev_reg = 32'hDEADBEEF;

        #(CYC * 2);
        reset = 0;

        // Wait for SDRAM initialization
        $display("Waiting for SDRAM Idle...");
        wait (sdram_inst.state == sdram_inst.STATE_IDLE);  // STATE_IDLE
        $display("SDRAM Initialized");

        // 1. Write Register
        write_reg(24'h000005, 32'h12345678);

        // Check result
        @(wr_reg_changed);
        assert (wr_reg == 32'h12345678)
        else $fatal(1, "Write Register Failed: Expected 12345678, got %h", wr_reg);
        assert (wr_reg_addr == 4'h5)
        else $fatal(1, "Write Register Addr Failed: Expected 5, got %h", wr_reg_addr);

        #(CYC * 2);

        // 2. Read Register
        // api.sv only responds to addr[3:0] == 1 for ev_reg
        begin
            logic [31:0] read_val;
            read_reg(24'h000001, read_val);
            assert (read_val == ev_reg)
            else $error("Read Register Failed: Expected %h, got %h", ev_reg, read_val);
        end

        #(CYC * 2);

        // 3. Write SDRAM
        write_mem(24'h001000, 16'h1234, 16'h5678);

        #(CYC * 2);

        // 4. Read SDRAM
        begin
            logic [15:0] r1, r2;
            read_mem(24'h001000, r1, r2);
            assert (r1 == 16'h1234)
            else $error("Read Mem Data1 mismatch: Expected 1234, got %h", r1);
            assert (r2 == 16'h5678)
            else $error("Read Mem Data2 mismatch: Expected 5678, got %h", r2);
        end

        #(CYC * 2);
        $display("Testbench completed");
        $finish;
    end

endmodule
