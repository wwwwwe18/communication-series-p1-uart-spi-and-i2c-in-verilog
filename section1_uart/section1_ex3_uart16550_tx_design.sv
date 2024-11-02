//*****************************************************
// Project		: UART 16550 TX
// File			: section1_ex3_uart16550_tx_design
// Editor		: Wenmei Wang
// Date			: 21/10/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps

// LCR (Line Control Register) is used TX

module uart_tx_top (

	input				clk, rst, baud_pulse, pen, thre, stb, sticky_parity, eps, set_break,
	input		[7:0]	din,
	input		[1:0]	wls,
	output	reg			pop, sreg_empty, tx

);

	typedef enum logic [1:0] {idle = 0, start = 1, send = 2, parity = 3} state_type;
	state_type state = idle;
	
	reg	[7:0]	shft_reg;
	reg			tx_data;
	reg			d_parity;
	reg	[2:0]	bitcnt = 0;
	reg	[4:0]	count = 5'd15;
	reg			parity_out;
	
	always@(posedge clk, posedge rst) begin	// Async reset
	
		if(rst) begin
		
			state		<= idle;
			count		<= 5'd15;
			bitcnt		<= 0;
			
			shft_reg	<= 8'bxxxx_xxxx;
			pop			<= 1'b0;
			sreg_empty	<= 1'b0;
			tx_data		<= 1'b1;	// Idle value
		
		end
		else if(baud_pulse) begin
		
			case(state)
			
				// Idle state
				idle: begin
				
					if(thre == 1'b0) begin	// csr.lsr.thre
					
						if(count != 0) begin
						
							count		<= count - 1;
							state		<= idle;
							
						end
						else begin
						
							count		<= 5'd15;
							state		<= start;
							bitcnt		<= {1'b1, wls};
							
							pop			<= 1'b1;	// Read TX FIFO
							shft_reg	<= din;		// Store FIFO data in shift reg
							sreg_empty	<= 1'b0;
							
							case(wls)
							
								// Odd ^ -> d_parity = 1
								2'b00: d_parity <= ^din[4:0];
								2'b01: d_parity <= ^din[5:0];
								2'b10: d_parity <= ^din[6:0];
								2'b11: d_parity <= ^din[7:0];
						
							endcase
						
							tx_data		<= 1'b0;	// Start bit
						
						end
					
					end
				
				end
				
				// Start state
				start: begin
				
					// Decide parity out
					case({sticky_parity, eps})
					
						2'b00: parity_out <= ~d_parity;	// Odd XNOR -> do not add
						2'b01: parity_out <= d_parity;	// Even pass
						2'b10: parity_out <= 1'b1;		// Set
						2'b11: parity_out <= 1'b0;		// Clear
				
					endcase
					
					if(count != 0) begin
					
						count		<= count - 1;
						state		<= start;
					
					end
					else begin
					
						count		<= 5'd15;
						state		<= send;
						
						tx_data		<= shft_reg[0];
						shft_reg	<= shft_reg >> 1;
					
					end
				
				end
			
				// Send state
				send: begin
				
					if(bitcnt != 0) begin
					
						if(count != 0) begin
					
							count		<= count - 1;
							state		<= send;
						
						end
						else begin
						
							count		<= 5'd15;
							bitcnt		<= bitcnt - 1;
							
							tx_data		<= shft_reg[0];
							shft_reg	<= shft_reg >> 1;
					
						end
					
					end
					else begin
					
						if(count != 0) begin
					
							count		<= count - 1;
							state		<= send;
						
						end
						else begin
						
							count		<= 5'd15;
							sreg_empty	<= 1'b1;
							
							// Check parity
							if(pen == 1'b1) begin
							
								count	<= 5'd15;
								state	<= parity;
								
								tx_data	<= parity_out;
							
							end
							else begin
							
								tx_data	<= 1'b1;	// Stop bit
								count	<= (stb == 1'b0) ? 5'd15 : (wls == 2'b00) ? 5'd23 : 5'd31;	// Stop bit 1, 1.5, 2 -> 16, 24, 32 clk cycle
								state	<= idle;
							
							end
						
						end
					
					end
				
				end
			
				// Parity state
				parity: begin
				
					if(count != 0) begin
					
						count		<= count - 1;
						state		<= parity;
					
					end
					else begin
					
						tx_data	<= 1'b1;	// Stop bit
						count	<= (stb == 1'b0) ? 5'd15 : (wls == 2'b00) ? 5'd23 : 5'd31;	// Stop bit 1, 1.5, 2 -> 16, 24, 32 clk cycle
						state	<= idle;
					
					end
				
				end
			
			endcase
		
		end
	
	end
	
	always@(posedge clk, posedge rst) begin
	
		if(rst)
		
			tx	<= 1'b1;
			
		else
		
			tx	<= tx_data & ~set_break;	// If set_break == 1, tx = 0

	end

endmodule