// (C) 2001-2025 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


////////////////////////////////////////////////////////////////////
//
//  ALTERA_ONCHIP_FLASH_BLOCK
//
//  Copyright (C) 1991-2013 Altera Corporation
//  Your use of Altera Corporation's design tools, logic functions 
//  and other software and tools, and its AMPP partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Altera Program License 
//  Subscription Agreement, Altera MegaCore Function License 
//  Agreement, or other applicable license agreement, including, 
//  without limitation, that your use is for the sole purpose of 
//  programming logic devices manufactured by Altera and sold by 
//  Altera or its authorized distributors.  Please refer to the 
//  applicable agreement for further details.
//
////////////////////////////////////////////////////////////////////

// synthesis VERILOG_INPUT_VERSION VERILOG_2001

`timescale 1 ps / 1 ps

module altera_onchip_flash_block (
	xe_ye,
	se,
	arclk,
	arshft,
	ardin,
	drclk,
	drshft,
	drdin,
	nprogram,
	nerase,
	nosc_ena,
	par_en,
	drdout,
	busy,
	se_pass,
	sp_pass,
	osc
);

	parameter FLASH_ADDR_WIDTH = 23;
	parameter FLASH_DATA_WIDTH = 32;
	parameter DEVICE_FAMILY	= "MAX 10";
	// !!!! Important !!!!
	// UNIQUE_IDENTIFIER is confidential and should not publish to external customer.
	parameter UNIQUE_IDENTIFIER = "altera_private_atom";
	// !!!! Important !!!!
	parameter PART_NAME = "Unknown";
	parameter IS_DUAL_BOOT = "False";
	parameter IS_ERAM_SKIP = "False";
	parameter IS_COMPRESSED_IMAGE = "False";
	parameter INIT_FILENAME = "";
	parameter MIN_VALID_ADDR = 1;
	parameter MAX_VALID_ADDR = 1;
	parameter MIN_UFM_VALID_ADDR = 1;
	parameter MAX_UFM_VALID_ADDR = 1;
	parameter ADDR_RANGE1_END_ADDR = 1;
    parameter ADDR_RANGE2_END_ADDR = 1;
	parameter ADDR_RANGE1_OFFSET = 1;
	parameter ADDR_RANGE2_OFFSET = 1;
    parameter ADDR_RANGE3_OFFSET = 1;
    
	// simulation only start
	parameter DEVICE_ID = "08";
	parameter INIT_FILENAME_SIM = "";
	// simulation only end
	
	input xe_ye;
	input se;
	input arclk;
	input arshft;
	input [FLASH_ADDR_WIDTH-1:0] ardin;
	input drclk;
	input drshft;
	input drdin;
	input nprogram;
	input nerase;
	input nosc_ena;
	input par_en;

	output [FLASH_DATA_WIDTH-1:0] drdout;
	output busy;
	output se_pass;
	output sp_pass;
	output osc;

	// -----------------------------------------------------------------------
	// Instantiate wysiwyg for ufm block according to device family
	// -----------------------------------------------------------------------
	generate
		if (DEVICE_FAMILY == "MAX 10" || DEVICE_FAMILY == "MAX 10 FPGA") begin
			fiftyfivenm_unvm # (
				.identifier (UNIQUE_IDENTIFIER),
				.part_name (PART_NAME),
				.is_dual_boot (IS_DUAL_BOOT),
				.is_eram_skip (IS_ERAM_SKIP),
				.is_compressed_image (IS_COMPRESSED_IMAGE),
				.init_filename (INIT_FILENAME),
				.min_valid_addr (MIN_VALID_ADDR),
				.max_valid_addr (MAX_VALID_ADDR),
				.min_ufm_valid_addr (MIN_UFM_VALID_ADDR),
				.max_ufm_valid_addr (MAX_UFM_VALID_ADDR),			
				.addr_range1_end_addr (ADDR_RANGE1_END_ADDR),
				.addr_range2_end_addr (ADDR_RANGE2_END_ADDR),
				.addr_range1_offset (ADDR_RANGE1_OFFSET),
				.addr_range2_offset (ADDR_RANGE2_OFFSET),
				.addr_range3_offset (ADDR_RANGE3_OFFSET),
				// simulation only start
				.device_id (DEVICE_ID),
				.init_filename_sim (INIT_FILENAME_SIM)
				// simulation only end
			) ufm_block (
				.xe_ye(xe_ye),
				.se(se),
				.arclk(arclk),
				.arshft(arshft),
				.ardin(ardin),
				.drclk(drclk),
				.drshft(drshft),
				.drdin(drdin),
				.nprogram(nprogram),
				.nerase(nerase),
				.nosc_ena(nosc_ena),
				.par_en(par_en),
				.drdout(drdout),
				.busy(busy),
				.se_pass(se_pass),
				.sp_pass(sp_pass),
				.osc(osc)
			);
		end
	endgenerate

endmodule

