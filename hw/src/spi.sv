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
    logic [6:0] read_buf, write_buf;
    bit [2:0] rx_cnt = 3'd7, tx_cnt = 3'd7;
    logic frame_end, frame_end_prev, deselect, deselect_prev;

    // SPI clock domain for receiving data
    always_ff @(posedge spi_clk or posedge spi_cs) begin
        if (spi_cs) begin
            rx_cnt   <= 3'd7;
            deselect <= 1;
        end else begin
            rx_cnt <= rx_cnt - 3'd1;
            deselect <= 0;
            frame_end <= 0;

            if (rx_cnt == 3'd0) begin
                bus.read  <= {read_buf, spi_mosi};
                frame_end <= 1;
            end else begin
                read_buf[rx_cnt-1] <= spi_mosi;
            end
        end
    end

    // SPI clock domain for sending data
    always_ff @(negedge spi_clk or posedge spi_cs) begin
        if (spi_cs) begin
            tx_cnt <= 3'd7;
        end else begin
            tx_cnt <= tx_cnt - 3'd1;

            if (tx_cnt == 3'd7) begin
                spi_miso  <= bus.write[tx_cnt];
                write_buf <= bus.write[6:0];
            end else begin
                spi_miso <= write_buf[tx_cnt];
            end
        end
    end

    // FPGA clock domain
    always_ff @(posedge clk) begin
        deselect_prev  <= deselect;
        frame_end_prev <= frame_end;
        bus.transm_end <= 0;
        bus.read_valid <= 0;

        if (!deselect_prev && deselect) begin
            bus.transm_end <= 1;
        end

        if (!frame_end_prev && frame_end) begin
            bus.read_valid <= 1;
        end
    end
endmodule
