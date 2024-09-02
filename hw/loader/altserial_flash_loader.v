// altserial_flash_loader blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN
// verilator lint_off UNUSEDPARAM

module altserial_flash_loader #(
    parameter INTENDED_DEVICE_FAMILY  = "",
    parameter ENABLE_QUAD_SPI_SUPPORT = 0,
    parameter ENABLE_SHARED_ACCESS    = "",
    parameter ENHANCED_MODE           = 0,
    parameter NCSO_WIDTH              = 0
) (
    input  dclkin,
    input  scein,
    input  sdoin,
    output data0out,
    input  noe,
    input  asmi_access_granted
);
endmodule
