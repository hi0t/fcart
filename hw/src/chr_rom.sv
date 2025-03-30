module chr_rom (
    input logic clk,
    input logic en,

    sdram_bus.master ram,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic ram_req = 0;
    logic [2:0] ram_req_sync;
    logic [12:0] addr_in;

    assign data = addr_in[0] ? ram.data_read[15:8] : ram.data_read[7:0];

    always_ff @(negedge ppu_rd) begin
        ram_req <= 0;
        if (ciram_ce) begin
            ram_req <= 1;
            addr_in <= addr;
        end
    end

    always_ff @(posedge clk) begin
        ram_req_sync <= {ram_req_sync[1:0], ram_req};
        if (en && !ram_req_sync[2] && ram_req_sync[1]) begin
            ram.we <= 0;
            ram.address <= {{10{1'b0}}, addr_in[12:1]};
            ram.req <= !ram.req;
        end
    end
endmodule
