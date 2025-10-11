module fifo #(
    parameter DEPTH = 8
) (
    input logic clk,
    input logic reset,

    input logic [7:0] wr_data,
    input logic wr_en,
    output logic full,

    output logic [7:0] rd_data,
    input logic rd_en,
    output logic empty
);
    localparam PTR_WIDTH = $clog2(DEPTH);

    logic [7:0] mem[DEPTH];
    logic [PTR_WIDTH:0] wr_ptr, rd_ptr;

    // Status flags - combinatorial based on pointer comparison
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) && (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);

    // Write logic
    always_ff @(posedge clk) begin
        if (reset) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'd1;
        end
    end

    // Read logic
    always_ff @(posedge clk) begin
        if (reset) begin
            rd_ptr <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'd1;
        end
    end

    // Output data
    assign rd_data = mem[rd_ptr[PTR_WIDTH-1:0]];
endmodule
