//*****************************************************
// Project		: SPI
// File			: section2_ex2_spi_design
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
	integer		bit_count = 0;
	
	// Generating sclk = (1/8) * clk
	always@(posedge clk) begin
	
		case(next_state)
		
			idle: begin
			
				spi_sclk <= 0;
			
			end
			
			start: begin
			
				if((count < 3'b011) || (count == 3'b111))
				
					spi_sclk <= 1'b1;
				
				else
				
					spi_sclk <= 1'b0;
			
			end
			
			tx_data: begin
			
				if((count < 3'b011) || (count == 3'b111))
				
					spi_sclk <= 1'b1;
				
				else
				
					spi_sclk <= 1'b0;
			
			end
			
			end_tx: begin
			
				if(count < 3'b011)
				
					spi_sclk <= 1'b1;
				
				else
				
					spi_sclk <= 1'b0;
			
			end
			
			default: spi_sclk <= 1'b0;
	
		endcase
	
	end
	
	// Sense reset
	always@(posedge clk) begin
	
		if(rst)
		
			state <= idle;
			
		else
		
			state <= next_state;
	
	end
	
	// next_state decoder - combinational process
	always@(*) begin
	
		case(state)
		
			idle: begin
			
				mosi	= 1'b0;
				cs		= 1'b1;
				
				if(tx_enable)
				
					next_state = start;
					
				else
				
					next_state =idle;
			
			end
			
			start: begin
			
				cs		= 1'b0;
				
				if(count == 3'b111)	// Single cycle of sclk
				
					next_state = tx_data;
					
				else
				
					next_state = start;
			
			end
			
			tx_data: begin
			
				mosi	= din[7-bit_count];	// MSB
				
				if(bit_count != 8) begin
				
					next_state = tx_data;
				
				end
				else begin
			
					mosi	= 1'b0;
					next_state 	= end_tx;
			
				end
				
			end
			
			end_tx: begin
			
				cs		= 1'b1;
				mosi	= 1'b0;
				
				if(count == 3'b111)	// Single cycle of sclk
				
					next_state = idle;
					
				else
				
					next_state = end_tx;
			
			end
			
			default: next_state = idle;
	
		endcase
	
	end
	
	// Counter
	always@(posedge clk) begin
	
		case(state)
		
			idle: begin
			
				count 		<= 0;	// sclk
				bit_count	<= 0;	// bit
			
			end
		
			start: count <= count + 1;
			
			tx_data: begin
			
				if(bit_count != 8) begin
				
					if(count < 3'b111) begin
				
						count		<= count + 1;
						
					end
					else begin
					
						count		<= 0;
						bit_count	<= bit_count + 1;
					
					end
				
				end
			
			end
			
			end_tx: begin
			
				count		<= count + 1;
				bit_count	<= 0;
			
			end
			
			default: begin
			
				count		<= 0;
				bit_count	<= 0;
			
			end
		
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