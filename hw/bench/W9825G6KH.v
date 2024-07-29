// Blackbox for the memory model
module W9825G6KH (
    Dq,
    Addr,
    Bs,
    Clk,
    Cke,
    Cs_n,
    Ras_n,
    Cas_n,
    We_n,
    Dqm
);

    `include "Config-AC.v"

    inout [data_bits - 1 : 0] Dq;
    input [row_bits - 1 : 0] Addr;  //Address for tRC
    input [1 : 0] Bs;  //bank select
    input Clk;
    input Cke;
    input Cs_n;
    input Ras_n;
    input Cas_n;
    input We_n;
    input [dm_bits-1 : 0] Dqm;
endmodule
