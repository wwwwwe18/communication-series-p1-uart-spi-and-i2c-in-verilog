//*****************************************************
// Project		: UART 16550 registers
// File			: section1_ex5_uart16550_reg_design
// Editor		: Wenmei Wang
// Date			: 01/11/2024
// Description	: Design
//*****************************************************

`timescale 1ns / 1ps

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
				addr : 2	Interrupt Identification Reg IIR (R) + FCR(FIFO control Reg)(new) (W)
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
	// old uart 8250 (16550 p) :  single byte buffer
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
		
			csr.lcr	<=din_i;
		
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
			4: dout_o <= 8'h00;		// mcr;
			5: dout_o <= lsr_temp;	// lsr
			6: dout_o <= 8'h00;		// msr
			7: dout_o <= scr_temp;	// scr
			default: ;
		
		endcase
	end
	
	assign csr_o = csr;

endmodule