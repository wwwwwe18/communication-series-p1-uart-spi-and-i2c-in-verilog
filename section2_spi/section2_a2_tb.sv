//*****************************************************
// Project		: Daisy chain configuration
// File			: section2_ex7_spi_daisy_chain_tb
// Editor		: Wenmei Wang
// Date			: 01/11/2024
// Description	: Testbench
//*****************************************************

module tb;

	reg				clk = 0, newd = 0;
	reg		[7:0]	din = 0;
	wire	[7:0]	dout;
	
	daisy_c dut (clk, newd, din, dout);

	always #5 clk = ~clk;
	
	initial begin
	
		repeat(5) @(posedge clk);
		newd = 1;
		din = 8'b1010_0111;
		@(posedge dut.master.sclk);
		newd = 0;
		@(posedge dut.master.cs);
		$stop;
		
	end

endmodule