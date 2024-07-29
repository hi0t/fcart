interface sdio_bus (
    input logic clk
);
    logic [5:0] req_cmd;
    logic [31:0] req_arg;
    logic req_valid;
    logic [31:0] resp_arg;
    logic [1:0] resp_valid;  // 0 - busy, 1 - ready, 2 - invalid

    modport host(input clk, resp_arg, resp_valid, output req_cmd, req_arg, req_valid);
    modport device(input clk, req_cmd, req_arg, req_valid, output resp_arg, resp_valid);
endinterface
