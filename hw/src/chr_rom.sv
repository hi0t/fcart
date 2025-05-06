module chr_rom (
    input logic clk,
    input logic en,

    sdram_bus.master ram,

    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic [1:0] ce_sync;
    logic [3:0][12:0] addr_sync;

    assign data = addr[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(posedge clk) begin
        ce_sync   <= {ce_sync[0], ciram_ce};
        addr_sync <= {addr_sync[2:0], addr};

        // Page mode read divided into atomic transactions. Refresh can be performed at any time.
        if (en && ce_sync[1] && (addr_sync[3] == addr_sync[2]) && (addr_sync[2] == addr_sync[1])) begin
            ram.we <= 0;
            ram.address <= {{10{1'b0}}, addr_sync[1][12:1]} + 22'h4000;
            ram.req <= 1;
        end else ram.req <= 0;
    end
endmodule
