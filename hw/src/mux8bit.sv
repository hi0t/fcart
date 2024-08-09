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
        STATE_CAPTURE,
        STATE_READING,
        STATE_REFRESH
    } state = STATE_CAPTURE;

    logic [2:0] read_sync;
    logic [ADDR_BITS-2:0] addr_cache;
    logic [15:0] data_cache;
    logic low_bit;

    assign data_read = low_bit ? data_cache[15:8] : data_cache[7:0];
    assign ram.data_write = 'x;

    always_ff @(posedge clk) begin
        // Synchronization of signals from m2
        read_sync <= {read_sync[1:0], read};

        case (state)
            STATE_CAPTURE:
            if (read_sync[2:1] == 2'b01) begin
                ram.refresh <= 0;
                low_bit <= address[0];
                if (addr_cache != address[ADDR_BITS-1:1]) begin
                    addr_cache <= address[ADDR_BITS-1:1];
                    ram.address <= address[ADDR_BITS-1:1];
                    ram.we <= 0;
                    ram.req <= ~ram.req;
                    state <= STATE_READING;
                end else state <= STATE_REFRESH;
            end
            STATE_READING:
            if (ram.req == ram.ack) begin
                data_cache <= ram.data_read;
                state <= STATE_REFRESH;
            end
            STATE_REFRESH:
            if (read_sync[2:1] == 2'b10) begin
                ram.refresh <= 1;
                state <= STATE_CAPTURE;
            end
            default;
        endcase
    end

    //(* noprune *) logic trigger;
    /*logic [7:0] chr_rom['h1FFF:0];

    logic [12:0] test_addr;

    initial begin
        $readmemh("../../rom/chr.mem", chr_rom);
    end*/
endmodule
