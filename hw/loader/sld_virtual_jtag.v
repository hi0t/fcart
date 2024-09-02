// sld_virtual_jtag blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN
// verilator lint_off UNUSEDPARAM

module sld_virtual_jtag #(
    parameter sld_auto_instance_index = "",
    parameter sld_instance_index = 0,
    parameter sld_ir_width = 0
) (
    output tck,
    output tdi,
    input  tdo,
    output virtual_state_sdr
);
endmodule
