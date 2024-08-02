module api #(
    parameter ADDR_BITS
) (
    sdram_bus.device ram,
    sdio_bus.device  sdio,

    output logic [ADDR_BITS-1:0] prg_offset = 0,
    output logic [ADDR_BITS-1:0] chr_offset = 0,
    output logic load_state = 1
);
    logic write_cmd = 0;
    assign ram.read = 0;
    assign ram.refresh = !write_cmd;

    always_ff @(posedge sdio.clk) begin
        sdio.resp_valid <= 0;

        if (write_cmd) begin
            sdio.resp_valid <= 1;
            sdio.resp_arg <= 0;
            write_cmd <= 0;
            ram.write <= 1;
        end

        if (sdio.req_valid) begin
            case (sdio.req_cmd)
                1: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    prg_offset <= sdio.req_arg == 0 ? '0 : ADDR_BITS'(1) << sdio.req_arg;
                    load_state <= 1;
                end
                2: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    chr_offset <= sdio.req_arg == 0 ? '0 : ADDR_BITS'(1) << sdio.req_arg;
                    load_state <= 1;
                end
                3: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    load_state <= 0;
                end
                4: begin
                    write_cmd <= 1;
                    ram.write <= 0;
                    ram.address <= {{ADDR_BITS - 17{1'b0}}, sdio.req_arg[31:16]};
                    ram.data_write <= sdio.req_arg[15:0];
                end
                default: sdio.resp_valid <= 2;
            endcase
        end
    end
endmodule
