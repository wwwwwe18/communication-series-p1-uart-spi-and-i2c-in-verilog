//*****************************************************
// Project		: UART 16550 RX
// File			: section1_ex4_uart16550_rx_design
// Editor		: Wenmei Wang
// Date			: 25/10/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps

module uart_rx_top (

	input			clk, rst, baud_pulse, rx, sticky_parity, eps,
	input			pen,
	input	[1:0]	wls,
	output	reg		push,
	output	reg		pe, fe, bi	// Parity error, frame error, break indicator

);

	typedef enum logic [2:0] {idle = 0, start = 1, read = 2, parity = 3, stop = 4} state_type;
	state_type state = idle;
	
	// Detect falling edge
	reg rx_reg = 1'b1;
	wire fall_edge;

	always@(posedge clk) begin
	
		rx_reg <= rx;
	
	end
	
	assign fall_edge = rx_reg;
	
	reg	[2:0]	bitcnt;
	reg	[3:0]	count = 0;
	reg	[7:0]	dout = 0;
	reg			pe_reg;	// Parity error
	
	always@(posedge clk, posedge rst) begin
	
		if(rst) begin
		
			state	<= idle;
			push	<= 1'b0;
			pe		<= 1'b0;
			fe		<= 1'b0;
			bi		<= 1'b0;
			bitcnt	<= 3'd0;
		
		end
		else begin
		
			push	<= 1'b0;
			
			if(baud_pulse) begin
			
				case(state)
				
					// Idle state
					idle: begin
					
						if(!fall_edge) begin	// Start of transmission
						
							state	<= start;
							count	<= 5'd15;
						
						end
						else begin
						
							state	<= idle;
						
						end
					
					end
					
					// Detect start
					start: begin
					
						count	<= count - 1;
						
						if(count == 5'd7) begin
						
							if(rx == 1'b1) begin
							
								state	<= idle;
								count	<= 5'd15;
							
							end
							else begin
							
								state	<= start;
							
							end
							
						end	
						else if(count == 0) begin
						
							state	<= read;
							count	<= 5'd15;
							bitcnt	<= {1'b1, wls};
						
						end
					
					end
					
					// Read byte from RX pin
					read: begin
					
						count	<= count - 1;
						
						if(count == 5'd7) begin
						
							case(wls)
							
								2'b00: dout <= {3'b000,	rx, dout[4:1]};	// 5-bit
								2'b01: dout <= {2'b00,	rx, dout[5:1]};	// 6-bit
								2'b10: dout <= {1'b0,	rx, dout[6:1]};	// 7-bit
								2'b11: dout <= {		rx, dout[7:1]};	// 8-bit
							
							endcase
							
							state	<= read;
						
						end
						else if(count == 0) begin
						
							if(bitcnt == 0) begin
							
								if(pen == 1'b1)	begin // Parity enabled
								
									state	<= parity;
									count	<= 5'd15;
									
									case({sticky_parity, eps})
									
										2'b00: pe_reg <= ~^{rx, dout};	// Odd parity - XNOR
										2'b01: pe_reg <= ^{rx, dout};	// Even parity
										2'b10: pe_reg <= ~rx;			// Parity should be 1
										2'b11: pe_reg <= rx;			// Parity should be 0
									
									endcase
								
								end
								else begin
								
									state	<= stop;
									count	<= 5'd15;
								
								end
							
							end
							else begin	// Send rest of bits
							
								bitcnt	<= bitcnt - 1;
								state	<= read;
								count	<= 5'd15;
							
							end
						
						end
					
					end
					
					// Detect parity error
					parity: begin
					
						count	<= count - 1;
						
						if(count == 5'd7) begin
						
							pe		<= pe_reg;
							state	<= parity;
						
						end
						else if(count == 0) begin
						
							state	<= stop;
							count	<= 5'd15;
						
						end
					
					end
					
					// Detect frame error
					stop: begin
					
						count	<= count - 1;
						
						if(count == 5'd7) begin
						
							fe		<= ~rx;	// Stop bit is 1 -> no frame error
							push	<= 1'b1;	// Store dout on FIFO
							state	<= stop;
						
						end
						else if(count == 0) begin
						
							state	<= idle;
							count	<= 5'd15;
						
						end
					
					end
				
					default: ;
				
				endcase
			
			end
		
		end
	
	end

endmodule