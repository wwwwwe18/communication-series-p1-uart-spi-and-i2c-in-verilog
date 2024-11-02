//*****************************************************
// Project		: UART 16550 RX
// File			: section1_ex4_uart16550_rx_tb
// Editor		: Wenmei Wang
// Date			: 25/10/2024
// Description	: Testbench
//*****************************************************

module uart_rx_tb;

	reg			clk, rst, baud_pulse, rx, sticky_parity, eps;
	reg			pen;
	reg	[1:0]	wls;
	wire		push;
	wire		pe, fe, bi;
	
	uart_rx_top rx_dut (clk, rst, baud_pulse, rx, sticky_parity, eps, pen, wls, push, pe, fe, bi);
	
	initial begin
	
		clk = 0;
		rst = 0;
		baud_pulse = 0;
		rx = 1;
		sticky_parity = 0;	// Sticky parity is off
		eps = 0;			// Off Parity
		pen = 1'b1; 		// Parity enabled
		wls = 2'b11;		// Data width: 8 bits
		// Parity we expect is odd parity ~^: if 1 -> parity error
	
	end
	
	always #5 clk = ~clk;
	
	reg	[7:0]	rx_reg = 8'h45;
	
	initial begin
	
		rst= 1'b1;
		repeat(5) @(posedge clk);
		
		// Start
		rst = 0;
		rx = 1'b0;
		repeat(16) @(posedge baud_pulse);
		
		// Send 8-bit data
		for(int i = 0; i < 8; i++) begin
		
			rx = rx_reg[i];
			repeat(16) @(posedge baud_pulse);
		
		end
		
		// Generate parity - odd
		rx = ~^rx_reg;
		repeat(16) @(posedge baud_pulse);
		
		// Generate stop
		rx = 1;
		repeat(16) @(posedge baud_pulse);
	
	end
	
	integer count = 5;
	
	// Generate baud_pulse
	always@(posedge clk) begin
	
		if(rst == 0) begin

			if(count != 0) begin
			
				count		<= count - 1;
				baud_pulse	<= 1'b0;
			
			end
			else begin
			
				count		<= 5;
				baud_pulse	<= 1'b1;
			
			end

		end
	
	end
	
endmodule