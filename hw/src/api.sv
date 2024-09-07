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
    logic write_chr = 0;
    logic load_state = 1;
    logic [1:0] load_state_sync;
    logic prg_req = 0;
    logic [1:0] prg_req_sync;
    logic chr_req = 0;
    logic [1:0] chr_req_sync;

    assign write_active = load_state_sync[1];
    assign prg.we = load_state_sync[1];
    assign chr.we = load_state_sync[1];
    assign prg.req = prg_req_sync[1];
    assign chr.req = chr_req_sync[1];

    always_ff @(posedge clk) begin
        prg_req_sync <= {prg_req_sync[0], prg_req};
        chr_req_sync <= {chr_req_sync[0], chr_req};
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
                    if (load_state) begin
                        write_prg <= 1;
                        prg_req <= !prg_req;
                        prg.address <= {{ADDR_BITS - 17{1'b0}}, sdio.req_arg[31:16]};
                        prg.data_write <= sdio.req_arg[15:0];
                    end else sdio.resp_valid <= 2;
                end
                2: begin
                    if (load_state) begin
                        write_chr <= 1;
                        chr_req <= !chr_req;
                        chr.address <= {{ADDR_BITS - 17{1'b0}}, sdio.req_arg[31:16]};
                        chr.data_write <= sdio.req_arg[15:0];
                    end else sdio.resp_valid <= 2;
                end
                3: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    load_state <= sdio.req_arg[0];
                end
                default: sdio.resp_valid <= 2;
            endcase
        end
    end
endmodule
