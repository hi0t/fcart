module api #(
    parameter ADDR_BITS
) (
    input logic clk,

    sdio_bus.device  sdio,
    sdram_bus.device ram,

    output logic [ADDR_BITS-1:0] prg_offset = 0,
    output logic [ADDR_BITS-1:0] chr_offset = 0,

    output logic write_active
);
    logic write_cmd = 0;
    logic [1:0] write_sync;
    logic load_state = 1;
    logic [1:0] load_state_sync;
    logic [ADDR_BITS-1:0] offset;

    assign write_active = load_state_sync[1];
    assign offset = sdio.req_arg == 0 ? '0 : ADDR_BITS'(1) << sdio.req_arg;

    always_ff @(posedge clk) begin
        write_sync <= {write_sync[0], write_cmd};
        if (write_sync[1]) begin
            ram.we  <= 1;
            ram.req <= ~ram.req;
        end

        load_state_sync <= {load_state_sync[0], load_state};
    end

    always_ff @(posedge sdio.clk) begin
        sdio.resp_valid <= 0;

        if (write_cmd) begin
            sdio.resp_valid <= 1;
            sdio.resp_arg <= 0;
            write_cmd <= 0;
        end

        if (sdio.req_valid) begin
            case (sdio.req_cmd)
                1: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    prg_offset <= offset;
                    load_state <= 1;
                end
                2: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    chr_offset <= offset;
                    load_state <= 1;
                end
                3: begin
                    sdio.resp_arg <= 0;
                    sdio.resp_valid <= 1;
                    load_state <= 0;
                end
                4: begin
                    write_cmd <= 1;
                    ram.address <= {{ADDR_BITS - 17{1'b0}}, sdio.req_arg[31:16]};
                    ram.data_write <= sdio.req_arg[15:0];
                end
                default: sdio.resp_valid <= 2;
            endcase
        end
    end
endmodule
