// PLL blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN
// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP
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
    parameter extend_oe_disable,
    parameter intended_device_family,
    parameter invert_output,
    parameter lpm_hint,
    parameter lpm_type,
    parameter oe_reg,
    parameter power_up_high,
    parameter width
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
