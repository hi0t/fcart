module chr_rom #(
    parameter ADDR_BITS
) (
    input logic clk,
    input logic enable,

    sdram_bus.device ram,
    input logic [ADDR_BITS-1:0] offset,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);

    enum bit [1:0] {
        STATE_LATCH,
        STATE_CE,
        STATE_READ_END,
        STATE_NEGEDGE
    } state = STATE_LATCH;

    logic [2:0] ppu_rd_sync;
    logic [1:0] ciram_ce_sync;
    logic [ADDR_BITS-1:0] addr_in;
    logic low_bit;
    bit [3:0] cnt;

    assign ram.data_write = 'x;

    // Requests to ROM via PPU bus
    always_ff @(posedge clk) begin
        ppu_rd_sync <= {ppu_rd_sync[1:0], ppu_rd};
        ciram_ce_sync <= {ciram_ce_sync[0], ciram_ce};
        addr_in <= {{ADDR_BITS - 13{1'b0}}, addr} | offset;
        cnt <= cnt + 1'd1;

        if (!enable) state <= STATE_LATCH;
        else
            case (state)
                STATE_LATCH:
                if (ppu_rd_sync[2:1] == 2'b01) begin  // Active readings
                    cnt   <= 0;
                    state <= STATE_CE;
                end else if ((ppu_rd_sync[2:1] == 2'b10) && ciram_ce_sync[1]) begin  // Single read
                    low_bit <= addr_in[0];
                    ram.address <= addr_in[ADDR_BITS-1:1];
                    ram.we <= 0;
                    ram.req <= ~ram.req;
                    state <= STATE_READ_END;
                end
                STATE_CE:
                // Waiting for the PPU address to stabilize. 12 cycles at 133 MHz
                if (cnt == 12) begin
                    if (ciram_ce_sync[1]) begin
                        low_bit <= addr_in[0];
                        ram.address <= addr_in[ADDR_BITS-1:1];
                        ram.we <= 0;
                        ram.req <= ~ram.req;
                        state <= STATE_READ_END;
                    end else state <= STATE_LATCH;
                end
                STATE_READ_END:
                if (ram.req == ram.ack) begin
                    data  <= low_bit ? ram.data_read[15:8] : ram.data_read[7:0];
                    state <= STATE_NEGEDGE;
                    cnt   <= 0;
                end
                STATE_NEGEDGE:
                if (!ppu_rd_sync[2] || cnt == ~4'b0) begin
                    state <= STATE_LATCH;
                end
                default;
            endcase
    end
endmodule
