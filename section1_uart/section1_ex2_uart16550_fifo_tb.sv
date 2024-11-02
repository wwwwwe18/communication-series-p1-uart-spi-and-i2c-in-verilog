//*****************************************************
// Project		: UART 16550 - FIFO
// File			: section1_ex2_uart16550_fifo_tb
// Editor		: Wenmei Wang
// Date			: 20/10/2024
// Description	: Testbench
//*****************************************************

module fifo_tb;

	reg				rst, clk, en, push_in, pop_in;
	reg		[7:0]	din;
	wire	[7:0]	dout;
	wire			empty, full, underrun, overrun;
	reg		[3:0]	threshold;
	wire			thre_trigger;
	
	initial begin
	
		rst = 0;
		clk = 0;
		en = 0;
		din = 0;
	
	end
	
	fifo_top dut_fifo (rst, clk, en, push_in, pop_in, din, dout, empty, full, underrun, overrun, threshold, thre_trigger);

	always #5 clk = ~clk;
	
	initial begin
	
		rst = 1'b1;
		repeat(5) @(posedge clk);
		
		// Write
		for(int i = 0; i < 20; i++) begin
		
			rst = 1'b0;
			push_in = 1'b1;
			din = $urandom();
			pop_in = 1'b0;
			en = 1'b1;
			threshold = 4'ha;
			@(posedge clk);
		
		end
		
		// Read
		for(int i = 0; i < 20; i++) begin
		
			rst = 1'b0;
			push_in = 1'b0;
			din = 0;
			pop_in = 1'b1;
			en = 1'b1;
			threshold = 4'ha;
			@(posedge clk);
		
		end
	
	end

endmodule