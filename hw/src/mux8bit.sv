module mux8bit #(
    parameter ADDR_BITS
) (
    input logic clk,

    sdram_bus.device ram,

    input logic read,
    input logic [ADDR_BITS-1:0] address,
    output logic [7:0] data_read
);
    enum bit [1:0] {
        STATE_READ_START,
        STATE_READ_END,
        STATE_POSEDGE
    } state = STATE_READ_START;

    logic [1:0] read_sync;
    logic [ADDR_BITS-1:0] addr_in;
    logic [ADDR_BITS-2:0] addr_cache;
    logic [15:0] data_cache;
    logic low_bit;

    assign data_read = low_bit ? data_cache[15:8] : data_cache[7:0];
    assign ram.data_write = 'x;

    always_ff @(posedge clk) begin
        // Synchronization of signals from m2
        read_sync <= {read_sync[0], read};
        addr_in   <= address;

        case (state)
            STATE_READ_START:
            if (read_sync[1]) begin
                low_bit <= addr_in[0];
                if (addr_cache != addr_in[ADDR_BITS-1:1]) begin
                    addr_cache <= addr_in[ADDR_BITS-1:1];
                    ram.address <= addr_in[ADDR_BITS-1:1];
                    ram.we <= 0;
                    ram.req <= ~ram.req;
                    state <= STATE_READ_END;
                end else state <= STATE_POSEDGE;
            end
            STATE_READ_END:
            if (ram.req == ram.ack) begin
                data_cache <= ram.data_read;
                state <= STATE_POSEDGE;
            end
            STATE_POSEDGE:
            if (~read_sync[1]) begin
                state <= STATE_READ_START;
            end
            default;
        endcase
    end
endmodule
