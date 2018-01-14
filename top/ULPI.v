module ULPI (
	input CLK_60M,
	input NRST_A_USB,

	//---------------------------------------------------------------------

	inout [7:0] USB_DATA,
	input USB_DIR,
	input USB_NXT,
	output USB_RESETN,
	output USB_STP,
	output USB_CS,

	//---------------------------------------------------------------------

	input REG_RW,	//negative when read
	input REG_EN,	//Strobe that we want to do REG operation
	input [5:0] REG_ADDR, 
	input [7:0] REG_DATA_I,
	output [7:0] REG_DATA_O,
	output REG_DONE,
	output REG_FAIL,

	output [7:0] RXCMD,

	output READY//,

	//---------------------------------------------------------------------

	//output [7:0] LED
);

`define PARAM_SIZE 8

parameter RESET = `PARAM_SIZE'd0;
parameter IDLE	      	= `PARAM_SIZE'd1;
parameter REG_WRITE  	= `PARAM_SIZE'd2;
parameter REG_WRITE_DATA = `PARAM_SIZE'd3;
parameter REG_WRITE_END = `PARAM_SIZE'd4;
parameter REG_READ      = `PARAM_SIZE'd5;
parameter REG_READ_DATA = `PARAM_SIZE'd6;
parameter REG_READ_END = `PARAM_SIZE'd7;
parameter PHY_HAS_ABORTED = `PARAM_SIZE'd8;
parameter POST_RESET    = `PARAM_SIZE'd9;

`define REG_MAP_SIZE 6
parameter FUNC_CTRL_REG = `REG_MAP_SIZE'h04;

reg [`PARAM_SIZE - 1 : 0] state, next_state;
reg [7:0] reg_val, rxcmd;
reg [5:0] reg_addr;

reg last_usb_dir;

wire [7:0] USB_DATA_I, USB_DATA_O;

wire now_write_a = !USB_DIR & !last_usb_dir;
wire now_read_a = USB_DIR & last_usb_dir;
reg usb_stupid_test;
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		state <= RESET;
		next_state <= IDLE;
		rxcmd <= 8'd0;
		reg_val <= 8'd0;
		reg_addr <= 6'd0;

		last_usb_dir <= 1'b0;
		usb_stupid_test <= 1'b0;
	end else begin
		
		last_usb_dir <= USB_DIR;

		case (state)
		RESET: begin
			state <= POST_RESET;
		end
		POST_RESET: begin
			if (!last_usb_dir && !USB_DIR) begin
				state <= IDLE;
			end
		end
		IDLE: begin
			usb_stupid_test <= 1'b0;
			if (last_usb_dir & USB_DIR) begin
				rxcmd <= USB_DATA_I;
			end

			if (REG_EN) begin
				case (REG_RW)
				1'b0: begin
					reg_val <= 8'd0;
					reg_addr <= REG_ADDR;
					state <= REG_READ;
					next_state <= IDLE;
				end
				1'b1: begin
					reg_val <= REG_DATA_I;
					reg_addr <= REG_ADDR;
					state <= REG_WRITE;
					if ((REG_ADDR == 6'h04) && (REG_DATA_I & 8'b00100000))
						next_state <= POST_RESET;
					else
						next_state <= IDLE;
				end
				default: begin
				end
				endcase
			end
		end
		REG_WRITE: begin
			if (!last_usb_dir & !USB_DIR) begin
				if (USB_NXT & usb_stupid_test) begin
					state <= REG_WRITE_DATA;
				end 
				usb_stupid_test <= 1'b1;

			end else begin
				state <= PHY_HAS_ABORTED;
			end
		end
		REG_WRITE_DATA: begin
			if (!last_usb_dir & !USB_DIR) begin
				if (!USB_NXT) begin
					state <= REG_WRITE_END;
				end
			end else begin
				state <= PHY_HAS_ABORTED;
			end
		end
		REG_WRITE_END: begin
//			if (!USB_NXT) // <- with this we have 2 cycles with USB_STP == 1...
			//Why?
			state <= next_state;
		end
		REG_READ: begin
			if (!last_usb_dir & !USB_DIR) begin
				if (USB_NXT) begin
					state <= REG_READ_DATA;
				end
			end else begin
				state <= PHY_HAS_ABORTED;
			end
		end
		REG_READ_DATA: begin
			if (last_usb_dir) begin
				reg_val <= USB_DATA_I;
				state <= REG_READ_END;
			end else if (!last_usb_dir && !USB_DIR && USB_NXT) begin
				state <= PHY_HAS_ABORTED;
			end
		end
		REG_READ_END: begin
			state <= next_state;
		end
		PHY_HAS_ABORTED: begin
			/* If the PHY aborts the RegWrite by asserting dir,
			   the Link must retry the RegWrite (TXCMD) when the bus is idle. */
			state <= IDLE;
		end	
		default: begin
			state <= IDLE;
		end
		endcase
	end
end

reg ready_a, USB_STP_a, REG_DONE_a, REG_FAIL_a;
reg [7:0] USB_DATA_O_a, REG_DATA_O_a;
reg [7:0] RXCMD_a;
always @(NRST_A_USB, state, reg_addr, reg_val, rxcmd, USB_NXT) begin
	case (state)
	RESET: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b1;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = 8'd0;
	end
	POST_RESET: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = 8'd0;
	end
	REG_WRITE: begin //Write TXCMD
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b10, reg_addr};

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	REG_WRITE_DATA: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = reg_val;

		REG_DATA_O_a = 8'd0;		
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	REG_WRITE_END: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b1;
		USB_DATA_O_a = reg_val;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b1;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	REG_READ: begin //send TXCMD
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b11, reg_addr};

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	REG_READ_DATA: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b11, reg_addr};

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	REG_READ_END: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = reg_val;
		REG_DONE_a = 1'b1;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	IDLE: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	PHY_HAS_ABORTED: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b1;

		RXCMD_a = rxcmd;
	end
	default: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;
	end
	endcase
	
end

assign RXCMD = RXCMD_a;
assign REG_DATA_O = REG_DATA_O_a; 

assign USB_CS = 1'b1;
assign USB_RESETN = NRST_A_USB;
assign USB_STP = USB_STP_a;
assign USB_DATA_O = USB_DATA_O_a;
assign READY = ready_a;
assign REG_DONE = REG_DONE_a;
assign REG_FAIL = REG_FAIL_a;

//assign LED = state;

assign USB_DATA_I = USB_DATA;
assign USB_DATA = (now_write_a == 1'b1) ? USB_DATA_O : 8'hzz;

endmodule
