module api #(
    parameter ADDR_BITS
) (
    input logic clk,

    sdio_bus.device  sdio,
    sdram_bus.device prg,
    sdram_bus.device chr,

    output logic write_active
);
    logic write_prg = 0;
    logic [1:0] write_prg_sync;
    logic write_chr = 0;
    logic [1:0] write_chr_sync;
    logic load_state = 1;
    logic [1:0] load_state_sync;

    assign write_active = load_state_sync[1];

    always_ff @(posedge clk) begin
        write_prg_sync <= {write_prg_sync[0], write_prg};
        if (write_prg_sync[1]) begin
            prg.we  <= 1;
            prg.req <= ~prg.req;
        end

        write_chr_sync <= {write_chr_sync[0], write_chr};
        if (write_chr_sync[1]) begin
            chr.we  <= 1;
            chr.req <= ~chr.req;
        end

        load_state_sync <= {load_state_sync[0], load_state};
    end

    always_ff @(posedge sdio.clk) begin
        sdio.resp_valid <= 0;

        if (write_prg) begin
            sdio.resp_valid <= 1;
            sdio.resp_arg <= 0;
            write_prg <= 0;
        end else if (write_chr) begin
            sdio.resp_valid <= 1;
            sdio.resp_arg <= 0;
            write_chr <= 0;
        end

        if (sdio.req_valid) begin
            case (sdio.req_cmd)
                1: begin
                    write_prg <= 1;
                    prg.address <= {{ADDR_BITS - 17{1'b0}}, sdio.req_arg[31:16]};
                    prg.data_write <= sdio.req_arg[15:0];
                    load_state <= 1;
                end
                2: begin
                    write_chr <= 1;
                    chr.address <= {{ADDR_BITS - 17{1'b0}}, sdio.req_arg[31:16]};
                    chr.data_write <= sdio.req_arg[15:0];
                    load_state <= 1;
                end
                3: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    load_state <= 0;
                end
                default: sdio.resp_valid <= 2;
            endcase
        end
    end
endmodule
