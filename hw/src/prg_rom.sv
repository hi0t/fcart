module prg_rom #(
    parameter ADDR_BITS
) (
    input  logic clk,
    input  logic enable,
    output logic refresh,

    sdram_bus.device ram,
    input logic [ADDR_BITS-1:0] offset,

    input logic m2,
    input logic cpu_rw,
    input logic rom_ce,
    input logic [14:0] addr,
    output logic [7:0] data
);
    enum bit [1:0] {
        STATE_READ_START,
        STATE_READ_END,
        STATE_POSEDGE
    } state = STATE_READ_START;

    logic read;
    logic [1:0] read_sync;
    logic [ADDR_BITS-1:0] addr_in;
    logic low_bit;
    logic [ADDR_BITS-2:0] addr_cache;
    logic [15:0] data_cache;

    assign read = !rom_ce && cpu_rw && m2;
    assign data = low_bit ? data_cache[15:8] : data_cache[7:0];
    assign ram.data_write = 'x;

    // Requests to ROM via CPU bus
    always_ff @(posedge clk) begin
        read_sync <= {read_sync[0], read};
        addr_in   <= {{ADDR_BITS - 15{1'b0}}, addr} | offset;
        refresh   <= 0;

        if (!enable) state <= STATE_READ_START;
        else
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
                    end else begin
                        refresh <= 1;
                        state   <= STATE_POSEDGE;
                    end
                end
                STATE_READ_END:
                if (ram.req == ram.ack) begin
                    data_cache <= ram.data_read;
                    state <= STATE_POSEDGE;
                end
                STATE_POSEDGE:
                if (!read_sync[1]) begin
                    state <= STATE_READ_START;
                end
                default;
            endcase
    end

endmodule
