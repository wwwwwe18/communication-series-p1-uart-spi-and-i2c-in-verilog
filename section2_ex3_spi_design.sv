//*****************************************************
// Project		: SPI - alternate implementation
// File			: section2_ex3_spi_design
// Editor		: Wenmei Wang
// Date			: 31/10/2024
// Description	: Design
//*****************************************************

// Master
module fsm_spi (

	input	wire	clk,
	input	wire	rst,
	input	wire	tx_enable,
	output	reg		mosi,
	output	reg		cs,
	output	wire	sclk

);

	typedef enum logic [1:0] {idle = 0, start = 1, tx_data = 2, end_tx = 3} state_type;
	state_type state, next_state;
	
	reg	[7:0]	din = 8'b1110_1011;
	reg			spi_sclk = 0;
	reg	[2:0]	ccount = 0;
	reg	[2:0]	count = 0;	// 0 - 7
	
	// Generating sclk = (1/8) * clk
	always@(posedge clk) begin
	
		if(!rst && tx_enable) begin
		
			if(ccount < 3)
			
				ccount <= ccount + 1;
				
			else
			
				ccount <= 0;
				spi_sclk <= ~spi_sclk;
		
		end
	
	end
	
	always@(posedge sclk) begin
	
		case(state)
		
			idle: begin
			
				mosi	<= 1'b0;
				cs		<= 1'b1;
				
				if(!rst && tx_enable) begin
				
					state	<= tx_data;
					cs		<= 1'b0;
					
				end
				else
				
					state	<= idle;
			
			end
			
			tx_data: begin
			
				if(count < 8) begin
				
					mosi	<= din[7 - count];	// MSB
					count	<= count + 1;
				
				end
				else begin
			
					mosi	<= 0;
					cs		<= 1'b1;
					state	<= idle;
			
				end
				
			end
			
			default: state <= idle;
	
		endcase
	
	end

	assign sclk = spi_sclk;

endmodule

// Slave
module spi_slave (

	input			sclk, mosi, ss,
	output	[7:0]	dout,
	output	reg		done

);

	integer count = 0;
	
	typedef enum logic [1:0] {idle = 0, sample = 1} state_type;
	state_type state;
	
	reg	[7:0]	data = 0;
	
	always@(negedge sclk) begin
	
		case(state)
		
			idle: begin
			
				done	<= 1'b0;
				
				if(ss == 1'b0)
				
					state <= sample;
					
				else
				
					state <= idle;
			
			end
			
			sample: begin
			
				if(count < 8) begin
				
					count	<= count + 1;
					data	<= {data[6:0], mosi}; // LSR - master sends MSB bit first
					state	<= sample;
				
				end
				else begin
				
					count	<= 0;
					state	<= idle;
					done	<= 1'b1;
				
				end
			
			end
		
			default: state <= idle;
		
		endcase
	
	end

	assign dout = data;

endmodule

// Top
module spi_top (

	input			clk, rst, tx_enable,
	output	[7:0]	dout,
	output			done

);

	wire mosi, ss, sclk;
	
	fsm_spi		spi_m (clk, rst, tx_enable, mosi, ss, sclk);
	spi_slave	spi_s (sclk, mosi, ss, dout, done);

endmodule