module ULPI (
	input CLK_60M,
	input NRST_A_USB,

	//---------------------------------------------------------------------

	inout [7:0] USB_DATA,
	input USB_DIR,
	input USB_FAULTN,
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

	output READY,

	//---------------------------------------------------------------------

	output [7:0] DATA_OUT,
	output WR_STRB,
	output END_STRB,

	//---------------------------------------------------------------------

	input [7:0] DATA_IN,
	output NXT_STRB,
	input IN_STRB,

	//---------------------------------------------------------------------

	output [7:0] LED
);

`define PARAM_SIZE 8

parameter RESET = `PARAM_SIZE'd1;
parameter POST_CTRL_REG_INIT_0 = `PARAM_SIZE'd2;
parameter IDLE	      	= `PARAM_SIZE'd3;
parameter REG_WRITE  	= `PARAM_SIZE'd4;
parameter REG_WRITE_DATA = `PARAM_SIZE'd5;
parameter REG_WRITE_END = `PARAM_SIZE'd6;
parameter REG_READ      = `PARAM_SIZE'd7;
parameter REG_READ_DATA = `PARAM_SIZE'd8;
parameter PHY_HAS_ABORTED = `PARAM_SIZE'd9;
parameter INIT_CTRL_REG = `PARAM_SIZE'd10;
parameter POST_RESET    = `PARAM_SIZE'd11;
parameter POST_CTRL_REG_INIT_1 = `PARAM_SIZE'd12;

`define REG_MAP_SIZE 6
parameter FUNC_CTRL_REG = `REG_MAP_SIZE'h04;

reg [`PARAM_SIZE - 1 : 0] state, state_tmp, state_after, state_after_tmp;
reg last_usb_dir, last_usb_dir_tmp;
reg now_write_tmp, now_read_tmp;
reg [7 : 0] rxcmd, rxcmd_tmp;
reg [5 : 0] reg_addr, reg_addr_tmp;
reg [7 : 0] reg_val, reg_val_tmp;
reg ready_tmp, ready;

//USB data wires
wire [7:0] USB_DATA_I;
wire [7:0] USB_DATA_O;

assign USB_DATA = (now_write_tmp == 1'b1) ? USB_DATA_O : 8'hzz;
assign USB_DATA_I = USB_DATA;
assign RXCMD = rxcmd_tmp;
assign REG_DATA_O = reg_val_tmp; 

reg received_part_tmp, received_part;

always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin

		state <= RESET;
		state_after <= IDLE;
		last_usb_dir <= 1'b0;
		rxcmd <= 8'd0;
		reg_addr <= 6'd0;
		reg_val <= 8'd0;

		ready <= 1'b0;
		received_part <= 1'b0;

	end else begin

		rxcmd <= rxcmd_tmp;
		last_usb_dir <= last_usb_dir_tmp;
		state <= state_tmp;
		state_after <= state_after_tmp;
		reg_addr <= reg_addr_tmp;
		reg_val <= reg_val_tmp;
	
		ready <= ready_tmp;

		received_part <= received_part_tmp;
	end
end

reg USB_CS_d, USB_RESETN_d, USB_STP_d;
reg [7:0] USB_DATA_O_d, DATA_OUT_d;
reg REG_DONE_d, REG_FAIL_d;
reg END_STRB_d, WR_STRB_d;
reg NXT_STRB_d;

assign USB_CS = USB_CS_d;
assign USB_RESETN = NRST_A_USB;
assign USB_STP = USB_STP_d;
assign USB_DATA_O = USB_DATA_O_d;
assign READY = ready;
assign LED = state;
assign REG_DONE = REG_DONE_d;
assign REG_FAIL = REG_FAIL_d;

assign DATA_OUT = DATA_OUT_d;
assign END_STRB = END_STRB_d;
assign WR_STRB = WR_STRB_d;

assign NXT_STRB = NXT_STRB_d;

//PHY may abort BUS by asserting DIR to 1!
always @(NRST_A_USB, state, ready, now_read_tmp, now_write_tmp, rxcmd, rxcmd_tmp, last_usb_dir, reg_addr, reg_val, state_after, received_part, USB_DATA_I, USB_DIR, USB_NXT, REG_EN, REG_RW, REG_DATA_I, REG_ADDR, DATA_IN, IN_STRB) begin
	USB_CS_d = 1'b1;
	ready_tmp = ready;
	USB_DATA_O_d = 8'd0;
	USB_STP_d = !NRST_A_USB;
	REG_DONE_d = 1'b0;
	REG_FAIL_d = 1'b0;

	DATA_OUT_d = 8'd0;
	END_STRB_d = 1'b0;
	WR_STRB_d = 1'b0;
	NXT_STRB_d = 1'b0;
		

	rxcmd_tmp = rxcmd;
	state_tmp = state;
	state_after_tmp = state_after;
	reg_addr_tmp = reg_addr;
	reg_val_tmp = reg_val;
	received_part_tmp = received_part;

	now_write_tmp = !last_usb_dir & !USB_DIR;
	now_read_tmp = last_usb_dir & USB_DIR;
	last_usb_dir_tmp = USB_DIR;

	if (received_part && (!now_read_tmp || !rxcmd_tmp[5:4])) begin

		received_part_tmp = 1'b0;
		END_STRB_d = 1'b1;

	end else if (now_read_tmp && state != POST_CTRL_REG_INIT_0 && state != POST_CTRL_REG_INIT_1 && state != REG_READ_DATA && state != POST_RESET && state != RESET) begin

		if (!USB_NXT) begin
			rxcmd_tmp = USB_DATA_I;
		end else begin
			// usb packet reception
			DATA_OUT_d = USB_DATA_I;
			WR_STRB_d = 1'b1;
			received_part_tmp = 1'b1;
		end

		// Fail reg write if we have simultanous RXCMD
		if (REG_EN)
			REG_FAIL_d = 1'b1;

	end else begin
	
		case (state)
		RESET: begin
			ready_tmp = 1'b0;
			USB_STP_d = 1'b1;
			if (!USB_DIR) begin
				state_tmp = POST_RESET;
			end
		end
		POST_RESET: begin
			if (now_read_tmp) begin
				rxcmd_tmp = USB_DATA_I;
				state_tmp = INIT_CTRL_REG;
			end	
		end
		POST_CTRL_REG_INIT_0: begin
			if (!USB_DIR) begin
				state_tmp = POST_CTRL_REG_INIT_1;
			end
		end
		POST_CTRL_REG_INIT_1: begin
			//We should get RX command now
			if (now_read_tmp) begin
				rxcmd_tmp = USB_DATA_I;
				state_tmp = IDLE;
			end
		end
		INIT_CTRL_REG: begin
			// reset ULPI PHY chip
			if (now_write_tmp) begin
				reg_addr_tmp = FUNC_CTRL_REG;
				reg_val_tmp = 8'b01100001; 
				state_tmp = REG_WRITE;
				state_after_tmp = POST_CTRL_REG_INIT_0;
			end	
		end
		REG_WRITE: begin //Write TXCMD
			USB_DATA_O_d = {2'b10, reg_addr};
			if (now_write_tmp) begin
				if (USB_NXT) begin
					state_tmp = REG_WRITE_DATA;
				end
			end else begin
				state_tmp = PHY_HAS_ABORTED;
			end
		end
		REG_WRITE_DATA: begin
			USB_DATA_O_d = reg_val;
			if (now_write_tmp) begin
				if (USB_NXT) begin
					state_tmp = REG_WRITE_END;
				end
			end else begin
				state_tmp = PHY_HAS_ABORTED;
			end
		end
		REG_WRITE_END: begin
			USB_DATA_O_d = reg_val;
			if (now_write_tmp || USB_NXT) begin // || USB_NXT - Figuire 27
				USB_STP_d = 1'b1;
				state_tmp = state_after;
				REG_DONE_d = 1'b1;
			end else begin
				state_tmp = PHY_HAS_ABORTED;
			end
		end
		REG_READ: begin //send TXCMD
			USB_DATA_O_d = {2'b11, reg_addr};
			if (now_write_tmp) begin
				if (USB_NXT) begin
					state_tmp = REG_READ_DATA;
				end
			end else begin
				state_tmp = PHY_HAS_ABORTED;
			end
		end
		REG_READ_DATA: begin
			if (now_read_tmp) begin
				reg_val_tmp = USB_DATA_I;
				state_tmp = state_after;
				REG_DONE_d = 1'b1;
//			end else if (USB_NXT) begin // Figure 24
//				state_tmp = PHY_HAS_ABORTED;
			end
		end
		IDLE: begin
			ready_tmp = 1'b1;
			state_after_tmp = IDLE;
			if (REG_EN) begin
				reg_addr_tmp = REG_ADDR;
				case (REG_RW)
				1'b0: begin
					state_tmp = REG_READ;	
				end
				1'b1: begin
					reg_val_tmp = REG_DATA_I;
					state_tmp = REG_WRITE;
				end
				default: begin
				end
				endcase
			end else if (IN_STRB) begin
			end
		end
		PHY_HAS_ABORTED: begin
			/* If the PHY aborts the RegWrite by asserting dir,
			   the Link must retry the RegWrite (TXCMD) when the bus is idle. */
			REG_FAIL_d = 1'b1;
			state_tmp = IDLE;
		end
		default: begin
			state_tmp = RESET;
		end
		endcase
	end
end
endmodule
