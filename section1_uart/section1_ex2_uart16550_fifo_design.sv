//*****************************************************
// Project		: UART 16550 - FIFO
// File			: section1_ex2_uart16550_fifo_design
// Editor		: Wenmei Wang
// Date			: 20/10/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps

module fifo_top(

	input			rst, clk, en, push_in, pop_in,	// Control
	input	[7:0]	din,
	output	[7:0]	dout,
	output			empty, full, underrun, overrun,	// Flag
	input	[3:0]	threshold,
	output			thre_trigger

);

	reg	[7:0]	mem	[16];
	reg	[3:0]	waddr = 0;

	logic	push, pop;
	
	//-----------------------------------------------------
	// Empty flag
	//-----------------------------------------------------
	reg	empty_t;
	always@(posedge clk, posedge rst) begin	// Asyn reset
	
		if(rst) begin
		
			empty_t <= 1'b0;
		
		end
		else begin
		
			case({push, pop})
			
				2'b01: empty_t <= (~|(waddr) | ~en);	// Read -> empty if waddr = 4'b0000
				2'b10: empty_t <= 1'b0;
				default: ;
			
			endcase
		
		end
	
	end
	
	//-----------------------------------------------------
	// Full flag
	//-----------------------------------------------------
	reg full_t;
	always@(posedge clk, posedge rst) begin	// Asyn reset
	
		if(rst) begin
		
			full_t <= 1'b0;
		
		end
		else begin
		
			case({push, pop})
			
				2'b10: full_t <= (&(waddr) | ~en);	// Write -> full if waddr = 4'b1111
				2'b01: full_t <= 1'b0;
				default: ;
			
			endcase
		
		end
	
	end
	
	//-----------------------------------------------------
	assign push	= push_in & ~full_t;	// User wants to write and FIFO is not full
	assign pop  = pop_in  & ~empty_t;	// User wants to read and FIFO is not empty
	
	//-----------------------------------------------------
	// Read FIFO -> always first element
	assign dout = mem[0];
	
	//-----------------------------------------------------
	// Write pointer update
	//-----------------------------------------------------
	always@(posedge clk, posedge rst) begin
	
		if(rst) begin
		
			waddr <= 4'h0;
		
		end
		else begin
		
			case({push, pop})
			
				2'b10: begin	// push -> write
				
					if((waddr != 4'hf) && (full_t == 1'b0))		// Free location in FIFO
					
						waddr <= waddr + 1;
						
					else
					
						waddr <= waddr;
				
				end
				
				2'b01: begin	// pop -> read
				
					if((waddr != 4'h0) && (empty_t == 1'b0))	// Data to be read
					
						waddr <= waddr - 1;
						
					else
					
						waddr <= waddr;
				
				end
				
				default: ;
		
			endcase
		
		end

	end
	
	//-----------------------------------------------------
	// Memory update
	//-----------------------------------------------------
	always@(posedge clk, posedge rst) begin
	
		case({push, pop})
		
			2'b00: ;
			
			2'b01: begin	// pop -> read
			
				for(int i = 0; i < 14; i++) begin	// Update memory
				
					mem[i] <= mem[i + 1];
				
				end
			
				mem[15] <= 8'h00;
			
			end
			
			2'b10: begin	// push -> write
			
				mem[waddr] <= din;
			
			end
			
			2'b11: begin
			
				// Read
				for(int i = 0; i < 14; i++) begin	// Update memory
				
					mem[i] <= mem[i + 1];
				
				end
			
				mem[15] <= 8'h00;
				
				// Write
				mem[waddr - 1] <= din;
			
			end
		
		endcase
	
	end
	
	//-----------------------------------------------------
	// No read on empty FIFO
	
	//-----------------------------------------------------
	// Underrun flag - if empty_t but user tries to pop (pop_in)
	//-----------------------------------------------------
	reg	underrun_t;
	always@(posedge clk, posedge rst) begin
	
		if(rst)
			
			underrun_t <= 1'b0;
			
		else if((empty_t == 1'b1) && (pop_in == 1'b1))
		
			underrun_t <= 1'b1;
			
		else
		
			underrun_t <= 1'b0;
	
	end
	
	//-----------------------------------------------------
	// Overrun flag - if full_t but user tries to push (push_in)
	//-----------------------------------------------------
	reg	overrun_t;
	always@(posedge clk, posedge rst) begin
	
		if(rst)
			
			overrun_t <= 1'b0;
			
		else if((full_t == 1'b1) && (push_in == 1'b1))
		
			overrun_t <= 1'b1;
			
		else
		
			overrun_t <= 1'b0;
	
	end
	
	//-----------------------------------------------------
	// Threshold flag - only in write
	//-----------------------------------------------------
	reg	thre_t;
	always@(posedge clk, posedge rst) begin
	
		if(rst)
			
			thre_t <= 1'b0;
			
		else if(push ^ pop)	// push == 1, pop == 0 -> write; push == 0, pop == 1 -> read (waddr won't increase)
		
			thre_t <= (waddr >= threshold) ? 1'b1 : 1'b0;
	
	end
	
	//-----------------------------------------------------
	assign	empty			= empty_t;
	assign	full			= full_t;
	assign	underrun		= underrun_t;
	assign	overrun			= overrun_t;
	assign	thre_trigger	= thre_t;

endmodule