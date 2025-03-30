module prg_rom (
    input logic clk,
    input logic en,

    sdram_bus.master ram,
    output logic refresh,

    input logic m2,
    input logic cpu_rw,
    input logic romsel,
    input logic [14:0] addr,
    output logic [7:0] data
);
    logic ram_req = 0;
    logic [2:0] ram_req_sync;
    logic [14:0] addr_in;
    logic can_refresh;
    logic [1:0] refresh_sync;

    assign data = addr_in[0] ? ram.data_read[15:8] : ram.data_read[7:0];
    assign refresh = refresh_sync[1];

    always_ff @(posedge m2) begin
        can_refresh <= 0;
        ram_req <= 0;
        if (!romsel && cpu_rw) begin
            if (addr_in[14:1] != addr[14:1]) begin
                ram_req <= 1;
                addr_in <= addr;
            end else begin
                can_refresh <= 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        ram_req_sync <= {ram_req_sync[1:0], ram_req};
        refresh_sync <= {refresh_sync[0], can_refresh};
        if (en && !ram_req_sync[2] && ram_req_sync[1]) begin
            ram.we <= 0;
            ram.address <= {{8{1'b0}}, addr_in[14:1]};
            ram.req <= !ram.req;
        end
    end
endmodule
