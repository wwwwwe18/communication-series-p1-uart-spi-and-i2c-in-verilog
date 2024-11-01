//*****************************************************
// Project		: Digilent PMOD DA4 (AD5628)
// File			: section2_ex6_spi_master_pmod_da4_tb
// Editor		: Wenmei Wang
// Date			: 01/11/2024
// Description	: Testbench
//*****************************************************

module tb;

	reg			clk100mhz = 0;
	wire		cs;
	wire		mosi;
	wire		sclk;
	reg			st_wrt = 1'b0;
	reg	[11:0]	data_in = 12'h0;
	wire		done;
	
	top dut (clk100mhz, cs, mosi, sclk, st_wrt, data_in, done); 

	always #5 clk100mhz = ~clk100mhz;
	
	initial begin
	
		st_wrt	= 1'b1;
		data_in	= 12'b1100_1011_0101;
	
	end

endmodule