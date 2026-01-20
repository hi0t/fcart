module fifo #(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 16
) (
    input logic wr_clk,
    input logic wr_reset,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic wr_en,
    output logic full,

    input logic rd_clk,
    input logic rd_reset,
    output logic [DATA_WIDTH-1:0] rd_data,
    input logic rd_en,
    output logic empty
);
    localparam PTR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem[DEPTH];
    logic [PTR_WIDTH:0] wr_addr, rd_addr;
    logic [PTR_WIDTH:0] wr_addr_next, rd_addr_next;
    logic [PTR_WIDTH:0] wr_gray, rd_gray;
    // Synchronization registers
    (* syn_preserve = 1 *)logic [1:0][PTR_WIDTH:0] wr2rd_gray;
    (* syn_preserve = 1 *)logic [1:0][PTR_WIDTH:0] rd2wr_gray;

    ////////////////// Write logic ////////////////
    // Write pointer handler
    assign wr_addr_next = wr_addr + 1;
    always @(posedge wr_clk or posedge wr_reset) begin
        if (wr_reset) begin
            wr_addr <= '0;
            wr_gray <= '0;
        end else if (wr_en && !full) begin
            wr_addr <= wr_addr_next;
            wr_gray <= wr_addr_next ^ (wr_addr_next >> 1);
        end
    end

    // FIFO memory write
    always @(posedge wr_clk) if (wr_en && !full) mem[wr_addr[PTR_WIDTH-1:0]] <= wr_data;

    // Read to write synchronizer
    always @(posedge wr_clk or posedge wr_reset) begin
        if (wr_reset) rd2wr_gray <= '0;
        else rd2wr_gray <= {rd2wr_gray[0], rd_gray};
    end

    // Write flag generation
    assign full = (rd2wr_gray[1] == {~wr_gray[PTR_WIDTH:PTR_WIDTH-1], wr_gray[PTR_WIDTH-2:0]});

    ////////////////// Read logic ////////////////
    // Read pointer handler
    assign rd_addr_next = rd_addr + 1;
    always @(posedge rd_clk or posedge rd_reset) begin
        if (rd_reset) begin
            rd_addr <= '0;
            rd_gray <= '0;
        end else if (rd_en && !empty) begin
            rd_addr <= rd_addr_next;
            rd_gray <= rd_addr_next ^ (rd_addr_next >> 1);
        end
    end

    // FIFO memory read
    assign rd_data = mem[rd_addr[PTR_WIDTH-1:0]];

    // Write to read synchronizer
    always @(posedge rd_clk or posedge rd_reset) begin
        if (rd_reset) wr2rd_gray <= '0;
        else wr2rd_gray <= {wr2rd_gray[0], wr_gray};
    end

    // Read flag generation
    assign empty = (wr2rd_gray[1] == rd_gray);
endmodule
