// PLL blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module pll (CLKI, CLKOP, LOCK);
    input wire CLKI;
    output wire CLKOP;
    output wire LOCK;
endmodule
