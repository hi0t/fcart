module fifo #(
    parameter DEPTH = 16
) (
    input logic wr_clk,
    input logic wr_reset,
    input logic [7:0] wr_data,
    input logic wr_en,
    output logic full,

    input logic rd_clk,
    input logic rd_reset,
    output logic [7:0] rd_data,
    input logic rd_en,
    output logic empty
);
    localparam PTR_WIDTH = $clog2(DEPTH);

    logic [7:0] mem[DEPTH];
    logic [PTR_WIDTH:0] wr_addr, rd_addr;  // 1 extra bit for full/empty
    logic [PTR_WIDTH:0] wr_addr_next, rd_addr_next;
    logic [PTR_WIDTH:0] wr_gray, rd_gray;
    logic [1:0][PTR_WIDTH:0] wr_gray_sync, rd_gray_sync;

    // Write logic
    // The write address is incremented on the write clock domain
    // and the write pointer is converted to gray code
    assign wr_addr_next = wr_addr + 1'd1;
    always_ff @(posedge wr_clk) begin
        if (wr_reset) begin
            wr_addr <= '0;
            wr_gray <= '0;
        end else if (wr_en && !full) begin
            mem[wr_addr[PTR_WIDTH-1:0]] <= wr_data;

            wr_addr <= wr_addr_next;
            wr_gray <= (wr_addr_next >> 1) ^ wr_addr_next;
        end
    end

    // Read logic
    // The read address is incremented on the read clock domain
    // and the read pointer is converted to gray code
    assign rd_addr_next = rd_addr + 1'd1;
    assign rd_data = mem[rd_addr[PTR_WIDTH-1:0]];
    always_ff @(posedge rd_clk) begin
        if (rd_reset) begin
            rd_addr <= '0;
            rd_gray <= '0;
        end else if (rd_en && !empty) begin
            rd_addr <= rd_addr_next;
            rd_gray <= (rd_addr_next >> 1) ^ rd_addr_next;
        end
    end

    // Synchronize the write pointer to the read clock domain
    // and the read pointer to the write clock domain
    always @(posedge wr_clk) rd_gray_sync <= {rd_gray_sync[0], rd_gray};
    always @(posedge rd_clk) wr_gray_sync <= {wr_gray_sync[0], wr_gray};

    // Flag generation
    assign full  = (rd_gray_sync[1] == {~wr_gray[PTR_WIDTH:PTR_WIDTH-1], wr_gray[PTR_WIDTH-2:0]});
    assign empty = (wr_gray_sync[1] == rd_gray);
endmodule
