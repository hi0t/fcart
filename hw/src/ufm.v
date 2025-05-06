// UFM blackbox
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module ufm (
    	input  wire        clock,                   //    clk.clk
		input  wire [11:0] avmm_data_addr,          //   data.address
		input  wire        avmm_data_read,          //       .read
		output wire [31:0] avmm_data_readdata,      //       .readdata
		output wire        avmm_data_waitrequest,   //       .waitrequest
		output wire        avmm_data_readdatavalid, //       .readdatavalid
		input  wire [1:0]  avmm_data_burstcount,    //       .burstcount
		input  wire        reset_n                  // nreset.reset_n
);
endmodule
