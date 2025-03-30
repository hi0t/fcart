// PLL blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module pll (CLKI, CLKOP, CLKOS, CLKOS2, LOCK);
    input wire CLKI;
    output wire CLKOP;
    output wire CLKOS;
    output wire CLKOS2;
    output wire LOCK;
endmodule
