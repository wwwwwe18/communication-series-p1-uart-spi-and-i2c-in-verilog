//*****************************************************
// Project		: UART
// File			: section1_ex1_uart_design
// Editor		: Wenmei Wang
// Date			: 20/10/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps

module uart_top
#(
	
	parameter	clk_freq = 1_000_000,
	parameter	baud_rate = 9600

)
(

	input			clk, rst,
	input			rx,
	input	[7:0]	dintx,
	input			newd,
	output			tx,
	output	[7:0]	doutrx,
	output			donetx,
	output			donerx
	
);

	uart_tx
	#(clk_freq, baud_rate)
	utx
	(clk, rst, newd, dintx, tx, donetx);
	
	uart_rx
	#(clk_freq, baud_rate)
	urx
	(clk, rst, rx, doutrx, donerx);

endmodule



// TX
module uart_tx
#(
	
	parameter	clk_freq = 1_000_000,
	parameter	baud_rate = 9600

)
(

	input			clk,
	input			rst,
	input			newd,
	input	[7:0]	data_tx,
	output	reg		tx,
	output	reg		donetx

);

	localparam	clkcount = clk_freq / baud_rate;
	
	integer count = 0;
	integer counts = 0;
	
	reg	uclk = 0;
	
	enum	bit[1:0]	{idle = 2'b00, start = 2'b01, transfer = 2'b10, done = 2'b11}	state;
	
	// uart_clock_gen
	always@(posedge clk) begin
	
		if(count < clkcount / 2)
		
			count <= count + 1;
			
		else begin
		
			count <= 0;
			uclk <= ~uclk;
		
		end
	
	end
	
	reg	[7:0]	din;
	
	// Reset decoder
	always@(posedge uclk) begin
	
		if(rst) begin
		
			state <= idle;
		
		end
		else begin
		
			case(state)
			
				idle: begin
				
					counts	<= 0;
					tx		<= 1'b1;
					donetx	<= 1'b0;
					
					if(newd) begin
					
						state	<= transfer;
						din		<= data_tx;
						tx		<= 1'b0;	// Start bit
					
					end
					else
					
						state <= idle;
				
				end
				
				transfer: begin
				
					if(counts <= 7) begin
					
						counts	<= counts + 1;
						tx		<= din[counts];
						state	<= transfer;
					
					end
					else begin
					
						counts	<= 0;
						tx		<= 1'b1;	// Stop bit
						state	<= idle;
						donetx	<= 1'b1;
					
					end
				
				end
				
				default: state <= idle;
			
			endcase
		
		end
	
	end

endmodule

// RX
module uart_rx
#(

	parameter	clk_freq = 1_000_000,
	parameter	baud_rate = 9600

)
(

	input				clk,
	input				rst,
	input				rx,
	output	reg	[7:0]	data_rx,
	output	reg			donerx

);

	localparam	clkcount = clk_freq / baud_rate;
	
	integer count = 0;
	integer counts = 0;
	
	reg	uclk = 0;
	
	enum	bit[1:0]	{idle = 2'b00, start = 2'b01}	state;
	
	// uart_clock_gen
	always@(posedge clk) begin
	
		if(count < clkcount / 2)
		
			count <= count + 1;
			
		else begin
		
			count <= 0;
			uclk <= ~uclk;
		
		end
	
	end
	
	always@(posedge uclk) begin
	
		if(rst) begin
		
			data_rx	<= 8'h00;
			counts	<= 0;
			donerx	<= 1'b0;
		
		end
		else begin
		
			case(state)
			
				idle: begin
				
					data_rx	<= 8'h00;
					counts	<= 0;
					donerx	<= 0;
					
					if(rx == 1'b0)	// Start bit
					
						state	<= start;
						
					else
					
						state	<= idle;
				
				end
				
				start: begin
				
					if(counts <= 7) begin
					
						counts	<= counts + 1;
						data_rx	<= {rx, data_rx[7:1]};
					
					end
					else begin
					
						counts	<= 0;
						donerx	<= 1'b1;
						state	<= idle;
					
					end
				
				end
				
				default: state <= idle;
				
			endcase
		
		end
	
	end

endmodule