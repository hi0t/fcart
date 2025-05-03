module chr_rom_ufm (
    input logic clk,
    input logic en,

    input logic ppu_rd,
    input logic ciram_ce,
    input logic [12:0] addr,
    output logic [7:0] data
);
    logic [31:0] chr_rom['h7FF:0];
    logic ufm_req, ufm_valid, ufm_wait;
    logic [11:0] ufm_addr = 0;
    logic [31:0] ufm_data;
    bit proc;
    logic [31:0] tmp_data;

    always_comb begin
        case (addr[1:0])
            2'd0: data = tmp_data[7:0];
            2'd1: data = tmp_data[15:8];
            2'd2: data = tmp_data[23:16];
            2'd3: data = tmp_data[31:24];
        endcase
    end

    always_ff @(posedge clk) begin
        ufm_req <= ufm_wait;

        if (ufm_addr < 12'h800 && !proc) begin
            ufm_req <= 1;
            proc <= 1;
        end

        if (ufm_valid) begin
            chr_rom[ufm_addr[10:0]] <= ufm_data;
            ufm_addr <= ufm_addr + 1'd1;
            if (ufm_addr[0] == 1) proc <= 0;
        end
    end

    always_ff @(negedge ppu_rd) begin
        if (ciram_ce && en) begin
            tmp_data <= chr_rom[addr[12:2]];
        end
    end

    ufm ufm (
        .clock(clk),
        .avmm_data_addr(ufm_addr),
        .avmm_data_read(ufm_req),
        .avmm_data_readdata(ufm_data),
        .avmm_data_waitrequest(ufm_wait),
        .avmm_data_readdatavalid(ufm_valid),
        .avmm_data_burstcount(2),
        .reset_n(1)
    );
endmodule
