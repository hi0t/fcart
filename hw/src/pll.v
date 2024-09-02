// PLL blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN
// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP
// verilator lint_off UNUSEDPARAM
module pll (
    inclk0,
    c0,
    locked
);

    input inclk0;
    output c0;
    output locked;

endmodule

module altddio_out #(
    parameter extend_oe_disable = 0,
    parameter intended_device_family = 0,
    parameter invert_output = 0,
    parameter lpm_hint = 0,
    parameter lpm_type = 0,
    parameter oe_reg = 0,
    parameter power_up_high = 0,
    parameter width = 0
) (
    aclr,
    datain_h,
    datain_l,
    outclock,
    dataout,
    aset,
    oe,
    outclocken,
    sclr,
    sset
);
    input aclr;
    input datain_h;
    input datain_l;
    input outclock;
    output dataout;
    input aset;
    input oe;
    input outclocken;
    input sclr;
    input sset;
endmodule
