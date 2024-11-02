//*****************************************************
// Project		: Assignment 1
// File			: section1_a1_tb
// Editor		: Wenmei Wang
// Date			: 02/11/2024
// Description	: Testbench
//*****************************************************

// Write a Verilog Testbench (TB) to verify the operation of our UART 16550A core. You are allowed to make the necessary changes to ensure correct receiver operation. Design and TB codes are mentioned in the Instructions tab.

module all_mod_tb;

	reg				clk, rst, wr, rd;
	reg				rx;
	reg		[2:0]	addr;
	reg		[7:0]	din;

	wire			tx;
	wire	[7:0]	dout;

	all_mod dut (clk, rst, wr, rd, rx, addr, din, tx, dout);

	initial begin
	
		rst		= 0;
		clk		= 0;
		wr		= 0;
		rd		= 0;
		addr	= 0;
		din		= 0;
		rx		= 1;
		
	end

	always #5 clk = ~clk;
	
	reg	[7:0]	rx_reg = 8'b0100_0101;

	initial begin
	
		rst = 1'b1;
		repeat(5)@(posedge clk);
		rst = 0;
		 
		// dlab = 1;
		@(negedge clk);
		wr   = 1;
		addr = 3'h3;
		din  = 8'b1000_0000;
		 
		// lsb latch = 08
		@(negedge clk);
		addr = 3'h0;
		din  = 8'b0000_1000;
		 
		// msb latch = 01
		@(negedge clk);
		addr = 3'h1;
		din  = 8'b0000_0001;
		 
		// dlab = 0, wls = 11 (8-bits), stb = 1 (single bit dur), pen = 1, eps = 0 (odd), sp = 0
		@(negedge clk);
		addr = 3'h3;
		din  = 8'b0000_1111;
		
		// push f0 in fifo (thr, dlab = 0)
		@(negedge clk);
		addr = 3'h0;
		din  = 8'b1111_0000;	// 10000 -> parity = 0
		
		// Enable FIFO
		@(negedge clk);
		addr = 3'h2;
		din  = 8'b0000_0001;
		
		// Send RX start bit
		rx = 0;
		
		// Send 8-bit data
		for(int i = 0; i < 8; i++) begin
		
			repeat(16) @(negedge dut.uart_tx_inst.baud_pulse);
			rx = rx_reg[i];
		
		end
		
		// Generate parity - odd
		repeat(16) @(negedge dut.uart_tx_inst.baud_pulse);
		rx = ~^rx_reg;
		
		// Generate stop
		repeat(16) @(negedge dut.uart_tx_inst.baud_pulse);
		rx = 1;
		
		@(posedge dut.uart_tx_inst.sreg_empty);
		repeat(48) @(posedge dut.uart_tx_inst.baud_pulse);
		
		$stop;
	
	end

endmodule