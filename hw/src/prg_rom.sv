module prg_rom (
    input logic clk,
    input logic en,

    sdram_bus.master ram,
    output logic refresh,

    input logic m2,
    input logic romsel,
    input logic [14:0] addr,
    output logic [7:0] data
);
    logic [13:0] addr_cached;
    logic [ 2:0] read_sync;
    logic [ 2:0] refresh_sync;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];
    assign refresh = !refresh_sync[2] && refresh_sync[1];

    always_ff @(posedge clk) begin
        read_sync <= {read_sync[1:0], !romsel};
        // Refresh is performed after the OE cycle is completed.
        refresh_sync <= {refresh_sync[1:0], !m2};

        if (en && !read_sync[2] && read_sync[1] && (addr_cached != addr[14:1])) begin
            ram.we <= 0;
            ram.address <= {{8{1'b0}}, addr[14:1]};
            ram.req <= 1;
            addr_cached <= addr[14:1];
        end else ram.req <= 0;
    end
endmodule
