`timescale 1us / 1ns

module fifo_tb;
    initial begin
        $timeformat(-9, 2, " ns", 20);
        $dumpfile("fifo.vcd");
        $dumpvars(0, fifo_tb);
    end

    logic wr_clk, rd_clk, wr_reset, rd_reset;
    logic [7:0] wr_data, rd_data;
    logic wr_en, rd_en;
    logic full, empty;
    logic [7:0] dataq[$], expected;

    localparam CYC = 0.5;
    always #(CYC / 2) wr_clk <= !wr_clk;
    always #((CYC + 1) / 2) rd_clk <= !rd_clk;

    fifo #(
        .DEPTH(16)
    ) fifo (
        .wr_clk(wr_clk),
        .wr_reset(wr_reset),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .full(full),
        .rd_clk(rd_clk),
        .rd_reset(rd_reset),
        .rd_data(rd_data),
        .rd_en(rd_en),
        .empty(empty)
    );

    initial begin
        wr_clk = 0;
        wr_reset = 1;
        wr_en = 0;

        @(posedge wr_clk) wr_reset = 0;

        repeat (2) begin
            for (int i = 0; i < 10; i++) begin
                @(posedge wr_clk iff !full);
                wr_en   = 1;
                wr_data = 8'($urandom);
                dataq.push_back(wr_data);

                @(posedge wr_clk) wr_en = 0;
            end
            #(CYC * 10);
        end
    end

    initial begin
        rd_clk = 0;
        rd_reset = 1;
        rd_en = 0;

        @(posedge rd_clk) rd_reset = 0;

        repeat (2) begin
            for (int i = 0; i < 10; i++) begin
                @(posedge rd_clk iff !empty);
                rd_en = 1;
                expected = dataq.pop_front();
                if (rd_data == expected) $display("time = %0t: rd_data = %h", $realtime, rd_data);
                else $fatal(1, "invalid data: expected %0h, got %0h", expected, rd_data);

                @(posedge rd_clk) rd_en = 0;
            end
        end

        $finish;
    end

endmodule
