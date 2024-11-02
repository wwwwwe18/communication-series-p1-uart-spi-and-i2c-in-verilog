//*****************************************************
// Project		: UART 16550
// File			: section1_ex6_uart16550_design
// Editor		: Wenmei Wang
// Date			: 01/11/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps


// -------------------------------------------------------------------
// TX
// -------------------------------------------------------------------

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

// -------------------------------------------------------------------
// RX
// -------------------------------------------------------------------

module uart_rx_top (

	input				clk, rst, baud_pulse, rx, sticky_parity, eps,
	input				pen,
	input		[1:0]	wls,
	output	reg			push,
	output	reg			pe, fe, bi,	// Parity error, frame error, break indicator
	output	reg	[7:0]	dout

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
	//reg	[7:0]	dout = 0;
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
		
			//push	<= 1'b0;	// Debug - Assignment 1
			
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

// -------------------------------------------------------------------
// Register
// -------------------------------------------------------------------

// FCR - FIFO Control Register
typedef struct packed {

	logic	[1:0]	rx_trigger;	// Receive trigger
	logic	[1:0]	reserved;	// reserved
	logic			dma_mode;	// DMA mode select
	logic			tx_rst;		// Transmit FIFO Reset
	logic       	rx_rst;		// Receive FIFO Reset
	logic			ena;		// FIFO enabled
	
} fcr_t;
 
// LCR
typedef struct packed {

	logic			dlab;    
	logic			set_break;     
	logic			stick_parity;     
	logic			eps; 
	logic			pen;
	logic			stb; 
	logic	[1:0]	wls; 
	
} lcr_t;
  
// LSR - Line Status Register
typedef struct packed {

	logic	rx_fifo_error;
	logic	temt;	// Transmitter Emtpy
	logic	thre;	// Transmitter Holding Register Empty
	logic	bi; 	// Break Interrupt
	logic	fe;		// Framing Error
	logic	pe;		// Parity Error
	logic	oe;		// Overrun Error
	logic	dr;		// Data Ready

} lsr_t;
  
// Struct to hold all registers
typedef struct {

	fcr_t			fcr; 
	lcr_t 			lcr; 
	lsr_t			lsr; 
	logic	[7:0]	scr;

} csr_t;
  
typedef struct packed {

	logic	[7:0]	dmsb;	//Divisor Latch MSB
	logic	[7:0]	dlsb;	//Divisor Latch LSB

} div_t;

module uart_reg (

	input				clk, rst,
	input				wr_i, rd_i,
	input				rx_fifo_empty_i,
	input				rx_oe, rx_pe, rx_fe, rx_bi, 
	input		[2:0]	addr_i,
	input		[7:0]	din_i,

	output				tx_push_o,	// Add new data to TX FIFO
	output				rx_pop_o,	// Read data from RX FIFO

	output				baud_out, 	// Baud pulse for both TX and RX

	output				tx_rst, rx_rst,
	output		[3:0]	rx_fifo_threshold,

	output	reg	[7:0]	dout_o,

	output		csr_t	csr_o,
	input		[7:0]	rx_fifo_in

);

	csr_t csr; // Temporary csr

	// Register structure
	/*
	Total 10 registers and address bus of size 3-bit (0-7)
	Seventh bit of data format registe / Divisor Latch access bit (DLAB)
	DLAB = 0 -> addr : 0	THR / RHR
				addr : 1	IER
	DLAB = 1 -> addr : 0	LSB of baud rate divisor
				addr : 1	MSB of baud rate divisor
	---------------------------------------------------           
				addr : 2	Interrupt Identification Reg IIR (R) + FCR (FIFO control Reg)(new) (W)
				addr : 3	Data format reg / LCR
				addr : 4	Modem control reg / MCR
				addr : 5	Serialization Status register / LSR
				addr : 6	Modem Status Reg / MSR
				addr : 7	Scratch pad reg / SPR
	------------------------------------------------------           
	*/

	// -------------------------------------------------------------------
	// THR -> temporary buffer for stroing data to be transmitted serially
	// Transmit Holding Register
	// -------------------------------------------------------------------
	// old uart 8250 (16550 p) : single byte buffer
	// 16550 : 16 byte of buffer
	// once wr is high push data to tx fifo
	// if wr = 1, addr = 0 and dlab = 0 then send push signal to TX FIFO
	
	wire	tx_fifo_wr;	// Write
	
	assign	tx_fifo_wr = wr_i & (addr_i == 3'b000) & (csr.lcr.dlab == 1'b0);
	assign	tx_push_o = tx_fifo_wr;	// Go to TX FIFO
	
	// -------------------------------------------------------------------
	// RHR -> Hold the data recv by the shift register serially
	// Receiver Buffer Register
	// -------------------------------------------------------------------
	// read the data and push in the RX FIFO
	// if rd = 1, addr = 0 and dlab = 0 then send pop signal to RX FIFO
	
	wire	rx_fifo_rd;	// Read

	assign	rx_fifo_rd = rd_i & (addr_i == 3'b000) & (csr.lcr.dlab == 1'b0);
	assign	rx_pop_o = rx_fifo_rd;	// Read data from rx fifo --> go to RX FIFO

	reg		[7:0]	rx_data;
	
	always@(posedge clk) begin
	
		if(rx_pop_o)
		
			rx_data	<= rx_fifo_rd;
	
	end
	
	// -------------------------------------------------------------------
	// Baud Generation Logic
	// -------------------------------------------------------------------
	/*
	typedef struct packed {

		logic	[7:0]	dmsb;	//Divisor Latch MSB
		logic	[7:0]	dlsb;	//Divisor Latch LSB

	} div_t;
	*/
	
	div_t dl;
	
	// Update dlsb if wr = 1, addr = 0 and dlab = 1
	always@(posedge clk) begin
	
		if(wr_i && (addr_i == 3'b000) && (csr.lcr.dlab == 1'b1))
	
			dl.dlsb	<= din_i;
	
	end
	
	// Update dmsb if wr = 1, addr = 1 and dlab = 1
	always@(posedge clk) begin
	
		if(wr_i && (addr_i == 3'b001) && (csr.lcr.dlab == 1'b1))
	
			dl.dmsb	<= din_i;
	
	end
	
	reg			update_baud;
	reg	[15:0]	baud_cnt = 0;
	reg			baud_pulse = 0;
	
	// Sense update in baud values
	always@(posedge clk) begin
	
		update_baud	<= wr_i & ((addr_i == 3'b000) | (addr_i == 3'b001)) & (csr.lcr.dlab == 1'b1);
	
	end
	
	// Baud counter
	always@(posedge clk, posedge rst) begin
	
		if(rst)
		
			baud_cnt	<= 16'h0;
			
		else if(update_baud || (baud_cnt == 16'h0000))
		
			baud_cnt	<= dl;
	
		else
		
			baud_cnt	<= baud_cnt - 1;
	
	end
	
	// Generate baud pulse when baud count reaches zero
	always@(posedge clk) begin
	
		baud_pulse	<= |dl & (~|baud_cnt);	// dl != 0, baud count reaches zero
	
	end
	
	assign baud_out	= baud_pulse;	// Baud pulse for both TX and RX
	
	// -------------------------------------------------------------------
	// FIFO Control Register (FCR)
	// Use to Enable FIFO Mode, Set FIFO Threshold, Clear FIFO
	// -------------------------------------------------------------------
	// 0	-> Enable TX and RX FIFO
	// 1	-> Clear RECV FIFO
	// 2	-> Clear TX FIFO
	// 3	-> DMA Mode Enable
	// 4-5	-> Reserved
	//
	// 6-7	-> FIFO Threshold / trigger level for RX FIFO
	// 00 - 1	byte
	// 01 - 4	bytes
	// 10 - 8	bytes
	// 11 - 14	bytes
	// threshold will enable interrupt request, level falls below thre will clear interrupt
	
	// FIFO write operation -> read data from user and update bits of fcr
	always@(posedge clk, posedge rst) begin
	
		if(rst) begin
		
			csr.fcr	<= 8'h00;
		
		end
		else if((wr_i == 1'b1) && (addr_i == 3'h2)) begin
		
			csr.fcr.rx_trigger	<= din_i[7:6];
			csr.fcr.dma_mode	<= din_i[3];
			csr.fcr.tx_rst		<= din_i[2];
			csr.fcr.rx_rst		<= din_i[1];
			csr.fcr.ena			<= din_i[0];
		
		end
		else begin
		
			csr.fcr.tx_rst		<= 1'b0;
			csr.fcr.rx_rst		<= 1'b0;
		
		end
	
	end
	
	assign tx_rst = csr.fcr.tx_rst;	// Reset TX and RX FIFO -> go to TX and RX FIFO
	assign rx_rst = csr.fcr.rx_rst;
	
	// Based on value of rx_trigger, generate threshold count for RX FIFO
	reg [3:0] rx_fifo_th_count = 0;
	
	always_comb begin
	
		if(csr.fcr.ena == 1'b0) begin
		
			rx_fifo_th_count = 4'd0;
			
		end
		else
		
			case(csr.fcr.rx_trigger)
			
				2'b00: rx_fifo_th_count = 4'd1;
				2'b01: rx_fifo_th_count = 4'd4;
				2'b10: rx_fifo_th_count = 4'd8;
				2'b11: rx_fifo_th_count = 4'd14;
				
			endcase
			
	end
	 
	assign rx_fifo_threshold = rx_fifo_th_count;   // Go to RX FIFO
	
	// -------------------------------------------------------------------
	// Line Control Register (LCR)
	// Define format of transmitted data
	// -------------------------------------------------------------------
	/*
	typedef struct packed {

		logic			dlab;    
		logic			set_break;     
		logic			stick_parity;     
		logic			eps; 
		logic			pen;
		logic			stb; 
		logic	[1:0]	wls; 
		
	} lcr_t;
	*/
	
	// 0000 1100
	lcr_t lcr;
	reg	[7:0] lcr_temp;
	
	// Write new data to lcr
	always@(posedge clk, posedge rst) begin
	
		if(rst)
		
			csr.lcr	<= 8'h00;
			
		else if((wr_i == 1'b1) && (addr_i == 3'h3)) begin
		
			csr.lcr	<= din_i;
		
		end
	
	end
	
	// Read lcr
	wire read_lcr;
	
	assign read_lcr = ((rd_i == 1'b1) & (addr_i == 3'h3));
	
	always@(posedge clk) begin
	
		if(read_lcr)
		
			lcr_temp <= csr.lcr;
			
	end
	
	// -------------------------------------------------------------------
	// Line Status Register (LSR)
	// -------------------------------------------------------------------
	
	/*
	typedef struct packed {

		logic	rx_fifo_error;
		logic	temt;	// Transmitter Emtpy
		logic	thre;	// Transmitter Holding Register Empty
		logic	bi; 	// Break Interrupt
		logic	fe;		// Framing Error
		logic	pe;		// Parity Error
		logic	oe;		// Overrun Error
		logic	dr;		// Data Ready

	} lsr_t;
	*/
	
	reg [7:0] LSR_temp;
	
	// ----- LSR -- Serialization Status register   ---> Read only register
	// - 8250
	// Trans Overwrite | Recv Overrun | Break | Parity Error | Framing Error | TXE | TBE | RxRDY 
	//      0                  1          2          3               4          5     6      7
	 
	//   -16550
	//	DR | OE | PE | FE | BI | THRE | TEMTRXFIFOE | RXFIFOE
	//     0 <--------------------------------------> 7 
	 
	//-------------------bit 0 ---------------------------------
	//bit 0 shows byte is rcvd in the rcv bufer and buffer can be read.
	// fifo will reset empty flag if data is present in rxfifo
	// LSR[0] <= ~empty_flag;
	// if flag is 1 / no data -> buffer is empty and do not require read
	//  flag is 0 / some data -> buffer have data and can be read
	 
	//-------------------bit 1 ---------------------------------
	// Overrun error  - Data recv from serial port is slower than it recv
	// occurs when data is recv after fifo is full and shift reg is already filled
	 
	 
	// -------------------- bit 2 -----------------------------
	// PE - Parity error 
	/*
	0 = No parity error has been detected,
	1 = A parity error has been detected with the character at the top of the receiver FIFO.
	*/
	 
	// -------------------- bit 3 -----------------------------
	// FE - Frame error 
	/*
	 A framing error occurs when the received character does not have a valid STOP bit. In
	response to a framing error, the UART sets the FE bit and waits until the signal on the RX pin goes high.
	*/
	 
	// -------------------- bit 4 -----------------------------
	// Bi - Break indicator
	/*
	The BI bit is set whenever the receive data input (UARTn_RXD) was held low for longer than a
	full-word transmission time. A full-word transmission time is defined as the total time to transmit the START, data,
	PARITY, and STOP bits. 
	*/
	 
	// -------------------- bit 5 -----------------------------
	// THRE
	/*
	0 = Transmitter FIFO is not empty. At least one character has been written to the transmitter FIFO. The transmitter
	FIFO may be written to if it is not full.
	1 = Transmitter FIFO is empty. The last character in the FIFO has been transferred to the transmitter shift register
	(TSR).
	*/
	 
	// -------------------- bit 6 -----------------------------
	// TEMT
	/*
	0 = Either the transmitter FIFO or the transmitter shift register (TSR) contains a data character.
	1 = Both the transmitter FIFO and the transmitter shift register (TSR) are empty
	*/
	// -------------------- bit 7 -----------------------------
	// RXFIFOE
	/*
	0 = There has been no error, or RXFIFOE was cleared because the CPU read the erroneous character from the
	receiver FIFO and there are no more errors in the receiver FIFO.
	1 = At least one parity error, framing error, or break indicator in the receiver FIFO.
	*/
	
	// Update content of LSR register
	always@(posedge clk, posedge rst) begin

		if(rst) begin
		
			csr.lsr <= 8'h60; // Both fifo and shift register are empty thre = 1 , tempt = 1  // 0110 0000
			
		end
		else begin

			csr.lsr.dr	<=	~rx_fifo_empty_i;
			csr.lsr.oe	<=	rx_oe;
			csr.lsr.pe	<=	rx_pe;
			csr.lsr.fe	<=	rx_fe;
			csr.lsr.bi	<=	rx_bi;
			
		end
		
	end
	
	// Read register contents
	reg [7:0] lsr_temp; 
	wire read_lsr;
	
	assign read_lsr = ((rd_i == 1) & (addr_i == 3'h5));
	
	always@(posedge clk) begin
	
		if(read_lsr)
		
			lsr_temp <= csr.lsr;
			
	end
	
	// -------------------------------------------------------------------
	// Scratch pad register
	// -------------------------------------------------------------------
	
	// write new data to lcr
	always @(posedge clk, posedge rst) begin
	
		if(rst) begin
		
			csr.scr <= 8'h00;
			
		end
		else if((wr_i == 1'b1) && (addr_i == 3'h7)) begin
		
			csr.scr <= din_i;
			
		end
		
	end
	
	reg [7:0] scr_temp; 
	wire read_scr;
	
	assign read_scr = ((rd_i == 1'b1) & (addr_i == 3'h7)); 
 
	always@(posedge clk) begin

		if(read_scr)
		
			scr_temp <= csr.scr; 
			
	end
	
	// -------------------------------------------------------------------
	always@(posedge clk) begin
	
		case(addr_i)
		
			0: dout_o <= csr.lcr.dlab ? dl.dlsb : rx_data;
			1: dout_o <= csr.lcr.dlab ? dl.dmsb : 8'h00;	// csr.ier
			2: dout_o <= 8'h00; 	// iir
			3: dout_o <= lcr_temp;	// lcr
			4: dout_o <= 8'h00;		// mcr
			5: dout_o <= lsr_temp;	// lsr
			6: dout_o <= 8'h00;		// msr
			7: dout_o <= scr_temp;	// scr
			default: ;
		
		endcase
	end
	
	assign csr_o = csr;

endmodule

// -------------------------------------------------------------------
// FIFO
// -------------------------------------------------------------------

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

// -------------------------------------------------------------------
// UART TOP
// -------------------------------------------------------------------
module all_mod(

	input			clk, rst, wr, rd,
	input			rx,
	input	[2:0]	addr,
	input	[7:0]	din,
	output			tx,
	output	[7:0]	dout
	
);

	csr_t			csr;
	
	wire			baud_pulse, pen, thre, stb; 
	
	wire			tx_fifo_pop;
	wire	[7:0]	tx_fifo_out;
	wire			tx_fifo_push;
	
	wire			r_oe, r_pe, r_fe, r_bi;
	
	wire			rx_fifo_pop;	// Debug - Assignment 1
	wire	[7:0]	rx_fifo_out;
	wire			rx_fifo_push;

	wire	[3:0]	rx_fifo_threshold;
	
	wire	[7:0]	rx_out;
	
	// UART Registers
	uart_reg uart_regs_inst (
	
	.clk (clk),
	.rst (rst),
	.wr_i (wr),
	.rd_i (rd),

	.rx_fifo_empty_i (),
	.rx_oe (),
	.rx_pe (r_pe),
	.rx_fe (r_fe),
	.rx_bi (r_bi),

	.addr_i (addr),
	.din_i (din),
	.tx_push_o (tx_fifo_push),
	.rx_pop_o (rx_fifo_pop),
	.baud_out (baud_pulse),
	.tx_rst (tx_rst),
	.rx_rst (rx_rst),
	.rx_fifo_threshold (rx_fifo_threshold),
	.dout_o (dout),
	.csr_o (csr),
	.rx_fifo_in(rx_fifo_out)
		
	);
	
	// TX logic
	uart_tx_top uart_tx_inst (
	
	.clk (clk),
	.rst (rst),
	.baud_pulse (baud_pulse),
	.pen (csr.lcr.pen),
	.thre (1'b0),
	.stb (csr.lcr.stb),
	.sticky_parity (csr.lcr.stick_parity),
	.eps (csr.lcr.eps),
	.set_break (csr.lcr.set_break),
	.din (tx_fifo_out),
	.wls (csr.lcr.wls),
	.pop (tx_fifo_pop),
	.sreg_empty (),	// sreg empty ier
	.tx (tx)

	);
 
	// TX FIFO
	fifo_top tx_fifo_inst (
	
	.rst (rst),
	.clk (clk),
	.en (csr.fcr.ena),
	.push_in (tx_fifo_push),
	.pop_in (tx_fifo_pop),
	.din (din),
	.dout (tx_fifo_out),
	.empty (),	// fifo empty ier
	.full (),
	.overrun (),
	.underrun (),
	.threshold (4'h0),
	.thre_trigger ()
	
	);
	
	//RX LOGIC
	uart_rx_top uart_rx_inst (
	
	.clk (clk),
	.rst (rst),
	.baud_pulse (baud_pulse),
	.rx (rx),
	.sticky_parity (csr.lcr.stick_parity),
	.eps (csr.lcr.eps),
	.pen (csr.lcr.pen),
	.wls (csr.lcr.wls),
	.push (rx_fifo_push),
	.pe (r_pe),
	.fe (r_fe),
	.bi (r_bi),
	.dout(rx_out)

	);
	
	// RX FIFO
	fifo_top rx_fifo_inst (
	
	.rst (rst),
	.clk (clk),
	.en (csr.fcr.ena),
	.push_in (rx_fifo_push),
	.pop_in (rx_fifo_pop),
	.din (rx_out),
	.dout (rx_fifo_out),
	.empty (),	// fifo empty ier
	.full (),
	.overrun (),
	.underrun (),
	.threshold (rx_fifo_threshold),
	.thre_trigger ()
	
	);
	
endmodule