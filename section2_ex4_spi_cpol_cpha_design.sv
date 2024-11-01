//*****************************************************
// Project		: CPOL & CPHA
// File			: section2_ex4_spi_cpol_cpha_design
// Editor		: Wenmei Wang
// Date			: 01/11/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps

module top ();

	// -----------------------------------------
	// CPOL
	// -----------------------------------------

	// parameter half_clk_period = 2;
	// clk_count = [($clog2(half_clock_period * 2) - 1) : 0] -> [(2-1) : 0] -> [1:0]
	// clk_edges = total_data_bits * 2

	reg			ready = 1;
	integer 	spi_edges = 0;
	reg			start = 0;
	reg	[2:0]	clk_count = 0;	// Debug - to wait sclk / 2
	reg			spi_l = 0, spi_t = 0;
	reg			sclk = 0;
	reg			clk = 0;
	reg			cpol = 0;
	
	always #5 clk = ~clk;
	
	initial begin
	
		@(posedge clk);
		start = 1;
		@(posedge clk);
		start = 0;
	
	end

	always@(posedge clk) begin
	
		if(start == 1'b1) begin
		
			ready		<= 1'b0;
			spi_edges	<= 16;				// For 8-bit data
			sclk		<= cpol;
		
		end
		else if(spi_edges > 0) begin
		
			spi_l	<= 1'b0;
			spi_t	<= 1'b0;
			
			if(clk_count == 2) begin		// Leading edges
			
				spi_l		<= 1'b1;
				sclk		<= ~sclk;
				spi_edges	<= spi_edges - 1;
				clk_count	<= clk_count + 1;
			
			end
			else if(clk_count == 4) begin	// Trailing edges
			
				spi_t		<= 1'b1;
				sclk		<= ~sclk;
				spi_edges	<= spi_edges - 1;
				clk_count	<= 1;			// Debug
			
			end
			else begin
			
				clk_count	<= clk_count + 1;
			
			end
	
		end
	
	end
	
	// -----------------------------------------
	// CPHA
	// -----------------------------------------
	
	reg			mosi = 0;
	reg			cpha = 0;
	reg	[7:0]	tx_data = 8'b1010_0011;
	reg	[2:0]	bit_count = 3'b111;			// MSB -> LSB
	reg			ready_t = 0;
	reg	[7:0]	tx_data_t;
	reg	[2:0]	state = 0;
	reg			cs = 1;
	integer		count = 0;

	always@(posedge clk) begin
	
		case(state)
		
			// Idle
			0: begin
			
				if(start) begin
				
					if(!cpha) begin			// Leading edge
					
						state	<= 1;
						cs		<= 1'b0;	// Start TX
					
					end
					else begin				// Trailing edge
					
						state	<= 3;		// Delay TX by edge
						cs		<= 1'b0;
					
					end
					
				end
				else
					
					state	<= 0;
			
			end
			
			// Start TX bit by bit
			1: begin
			
				if(count < 3) begin					// Single sclk period
				
					count	<= count + 1;
					mosi	<= tx_data[bit_count];	// MSB first
					state	<= 1;
				
				end
				else begin
				
					count	<= 0;
					
					if(bit_count != 0) begin
					
						bit_count	<= bit_count - 1;
						state		<= 1;
					
					end
					else
					
						state		<= 2;			// End TX
				
				end
			
			end
			
			// End TX
			2: begin
			
				cs			<= 1'b1;
				bit_count	<= 3'b111;
				mosi		<= 1'b0;
				state		<= 0;					// Idle
			
			end
			
			// Delay
			3: begin
			
				state	<= 4;
			
			end
			
			4: begin
			
				state	<= 1;
			
			end
		
			default: state	<= 0;
		
		endcase
	
	end

endmodule