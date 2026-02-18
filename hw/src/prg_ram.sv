module prg_ram #(
    parameter ADDR_BITS = 23  // SDRAM width + 1
) (
    input logic clk,
    input logic m2,
    sdram_bus.controller ram,
    output logic refresh,

    input logic [ADDR_BITS-1:0] addr,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    input logic oe,
    input logic we
);
    logic [ADDR_BITS-2:0] addr_cached;
    logic [3:0] m2_sync;
    logic [7:0] data_in_reg;
    logic schedule_write;
    logic [2:0] we_sync;

    assign data_out = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    // Capture data for write on falling M2 edge
    always_ff @(negedge m2) data_in_reg <= data_in;

    always_ff @(posedge clk) begin
        ram.req <= 1'b0;
        refresh <= 1'b0;
        m2_sync <= {m2_sync[2:0], m2};
        we_sync <= {we_sync[1:0], we};

        if (m2_sync[3:1] == 3'b011) begin
            // Latch address on rising edge of M2 with little delay to wait for ROMSEL signal
            ram.address <= addr[ADDR_BITS-1:1];
            ram.wm <= addr[0] ? 2'b01 : 2'b10;

            if (oe) begin
                if (addr_cached != addr[ADDR_BITS-1:1]) begin
                    ram.we <= 1'b0;
                    ram.req <= 1'b1;
                    addr_cached <= addr[ADDR_BITS-1:1];
                end else begin
                    refresh <= 1'b1;
                end
            end

            schedule_write <= we;
        end

        if (schedule_write && we_sync[2:1] == 2'b10) begin
            ram.we <= 1'b1;
            ram.data_write <= {data_in_reg, data_in_reg};
            ram.req <= 1'b1;
            schedule_write <= 1'b0;
        end
    end
endmodule
