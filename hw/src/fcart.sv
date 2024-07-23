module fcart (
    input logic CLK,

    // SDIO interface
    input logic SDIO_CLK,
    inout wire  SDIO_CMD,

    // SDRAM chip interface
    inout wire [15:0] SDRAM_DQ,
    output logic [12:0] SDRAM_ADDR,
    output logic [1:0] SDRAM_BA,
    output logic SDRAM_CLK,
    output logic SDRAM_CKE,
    output logic SDRAM_CS,
    output logic SDRAM_RAS,
    output logic SDRAM_CAS,
    output logic SDRAM_WE,
    output logic [1:0] SDRAM_DQM
);
    logic [ 5:0] req_cmd;
    logic [31:0] req_arg;
    logic        req_valid;
    logic [31:0] resp_arg;
    logic [ 1:0] resp_valid;

    logic        read_cmd = 0;
    logic        write_cmd = 0;
    logic [23:0] address;
    logic [15:0] read_data;
    logic [15:0] write_data;

    assign SDRAM_CLK = CLK;

    sdio sdio (
        .clk_sdio(SDIO_CLK),
        .cmd_sdio(SDIO_CMD),
        .req_cmd(req_cmd),
        .req_arg(req_arg),
        .req_valid(req_valid),
        .resp_arg(resp_arg),
        .resp_valid(resp_valid)
    );

    sdram #(
        .ADDR_BITS  (13),
        .COLUMN_BITS(9)
    ) ram (
        .clk(CLK),
        .read_req(read_cmd),
        .write_req(write_cmd),
        .address_req(address),
        .data_in(write_data),
        .data_out(read_data),
        .busy(),
        .cke(SDRAM_CKE),
        .cs(SDRAM_CS),
        .address(SDRAM_ADDR),
        .bank(SDRAM_BA),
        .dq(SDRAM_DQ),
        .ras(SDRAM_RAS),
        .cas(SDRAM_CAS),
        .we(SDRAM_WE),
        .dqm(SDRAM_DQM)
    );


    always_ff @(posedge SDIO_CLK) begin
        resp_valid <= 1;

        if (read_cmd) begin
            resp_valid <= 0;
            resp_arg   <= {16'b0, read_data};
            read_cmd   <= 0;
        end else if (write_cmd) begin
            resp_valid <= 0;
            resp_arg   <= 0;
            write_cmd  <= 0;
        end

        if (req_valid) begin
            case (req_cmd)
                1: begin
                    read_cmd <= 1;
                    address  <= {8'b0, req_arg[15:0]};
                end
                2: begin
                    write_cmd <= 1;
                    address <= {8'b0, req_arg[15:0]};
                    write_data <= req_arg[31:16];
                end
                default: resp_valid <= 2;
            endcase
        end
    end
endmodule
