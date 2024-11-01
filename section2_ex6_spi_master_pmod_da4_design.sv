//*****************************************************
// Project		: Digilent PMOD DA4 (AD5628)
// File			: section2_ex6_spi_master_pmod_da4_design
// Editor		: Wenmei Wang
// Date			: 01/11/2024
// Description	: Design
//*****************************************************

module top (

	input			clk100mhz,
	output	reg		cs,
	output	reg		mosi,
	output	reg		sclk,		// 1MHz
	input			st_wrt,
	input	[11:0]	data_in,
	output	reg		done

);

	typedef enum logic [1:0] {idle_dac = 0, init_dac = 1, dac_data = 2, send_data = 3} state_type;
	state_type state;
	
	// Counter for DAC's output
	integer		count = 0;
	reg	[31:0]	data = 32'h0;
	reg	[31:0]	setup_dac = 32'h0800_0001;	// Magic num to initial the internal register
	reg			dac_init = 1'b0;
	
	// Local clock signals
	integer		clkdiv = 0;
	reg			clk1mhz = 1'b0;
	
	// Clock generation process - 100MHz to 1MHz
	always@(posedge clk100mhz) begin
	
		//if(clkdiv == 49) begin
		if(clkdiv == 4) begin	// For sim
		
			clkdiv	<= 0;
			clk1mhz	<= ~clk1mhz;
		
		end
		else begin
		
			clkdiv	<= clkdiv + 1;
		
		end
	
	end
	
	// DAC main process
	always@(posedge clk1mhz or negedge st_wrt) begin
	
		if(!st_wrt) begin
		
			cs		<= 1'b1;
			mosi	<= 1'b0;
			count	<= 0;
			done	<= 1'b0;
			state	<= idle_dac;
		
		end
		else begin
		
			case(state)
		
				idle_dac: begin
				
					cs		<= 1'b1;
					mosi	<= 1'b0;
					count	<= 0;
					done	<= 1'b0;
					
					if(!dac_init) begin	// Initilize DAC
					
						cs		<= 1'b1;
						state	<= init_dac;
					
					end
					else begin
					
						cs		<= 1'b1;
						state	<= dac_data;
					
					end
				
				end
				
				// Initialize DAC to magic number
				init_dac: begin
				
					if(count < 32) begin
					
						cs		<= 1'b0;					// cs enabled and send bit at the same time
						count	<= count + 1;
						mosi	<= setup_dac[31 - count];	// MSB -> LSB
						state	<= init_dac;
					
					end
					else begin
					
						cs			<= 1'b1;				// End TX
						count		<= 0;
						dac_init	<= 1'b1;				// DAC initialized
						state		<= dac_data;
					
					end
				
				end
				
				dac_data: begin
				
					cs		<= 1'b1;
					mosi	<= 1'b0;
					data	<= {12'h030, data_in, 8'h00};	
					state	<= send_data;
				
				end
				
				send_data: begin
				
					if(count < 32) begin
					
						cs		<= 1'b0;				// Start TX
						count	<= count + 1;
						mosi	<= data[31 - count];	// MSB -> LSB
						state	<= send_data;
					
					end
					else begin
					
						cs		<= 1'b1;
						count	<= 0;
						done	<= 1'b1;
						state	<= idle_dac;
					
					end
				
				end
				
				default: state	<= idle_dac;
		
			endcase
		
		end
	
	end

	assign sclk = clk1mhz;	// Drive DAC with locally generated 1MHz clock

endmodule