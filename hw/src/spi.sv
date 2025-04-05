module spi (
    input logic clk,

    // SPI signals
    input  logic spi_clk,
    input  logic spi_cs,
    input  logic spi_mosi,
    output logic spi_miso,

    // SPI interface
    spi_bus.slave bus
);
    bit   [2:0] bit_cnt;
    logic [7:0] write_buf;
    logic frame_end, frame_end_prev, frame_start, frame_start_prev;

    assign spi_miso = (bit_cnt == 3'd0) ? bus.data_write[7] : write_buf[7];
    assign frame_start = (bit_cnt == 3'd1);
    assign frame_end = (bit_cnt == 3'd7);

    always_ff @(posedge spi_clk or posedge spi_cs) begin
        if (spi_cs) begin
            bit_cnt <= 3'd0;
        end else begin
            bit_cnt <= bit_cnt + 3'd1;

            bus.data_read <= {bus.data_read[6:0], spi_mosi};

            if (bit_cnt == 3'd0) write_buf <= {bus.data_write[6:0], 1'b0};
            else write_buf <= {write_buf[6:0], 1'b0};
        end
    end

    // send a pulse to the main clock about a frame boundary
    always_ff @(posedge clk) begin
        frame_start_prev <= frame_start;
        frame_end_prev <= frame_end;
        bus.can_write <= (!frame_start_prev && frame_start);
        bus.read_valid <= (!frame_end_prev && frame_end);
    end
endmodule
