module fcart (
    input logic clk,

    input  logic key_in,
    output logic key_out,

    output logic [7:0] led,

    // SDIO interface
    input logic clk_sdio,
    inout wire  cmd_sdio
);
    logic [5:0] req_cmd;
    logic [31:0] req_arg;
    logic req_valid;
    logic [31:0] resp_arg;
    logic [1:0] resp_valid;

    sdio sdio (
        .clk_sdio(clk_sdio),
        .cmd_sdio(cmd_sdio),
        .req_cmd(req_cmd),
        .req_arg(req_arg),
        .req_valid(req_valid),
        .resp_arg(resp_arg),
        .resp_valid(resp_valid)
    );

    assign key_out = key_in;

    always_ff @(posedge clk_sdio) begin
        if (req_valid) begin
            case (req_cmd)
                1: begin
                    led <= req_arg[7:0];
                    resp_arg <= 1;
                    resp_valid <= 0;
                end
                default: resp_valid <= 2;
            endcase
        end else resp_valid <= 1;
    end
endmodule
