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
	output REG_FAIL, // WARNING! If we are in READ_DATA state, this output
			 // is always 1, even if we have not failed!

	output [7:0] RXCMD,

	output READY,

	//---------------------------------------------------------------------

	input [7:0] USB_DATA_IN,
	output USB_DATA_IN_STRB,	// next chunk ready for reception
	input USB_DATA_IN_START_END,	// if IN_START_END == '1', TRANSMISSION STARTS OR ENDS
	output USB_DATA_IN_FAIL, //WARNING! The same behavior as in REG_FAIL output

	//---------------------------------------------------------------------
	
	output [7:0] USB_DATA_OUT,
	output USB_DATA_OUT_STRB,
	output USB_DATA_OUT_END,
	output USB_DATA_OUT_FAIL, //WARNING! The same behavior as in REG_FAIL output
	
	output [7:0] STATE
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
parameter POST_RESET    = `PARAM_SIZE'd9;
parameter READ_DATA = `PARAM_SIZE'd10;
parameter READ_DATA_END = `PARAM_SIZE'd11;
parameter WRITE_DATA_PID = `PARAM_SIZE'd12;
parameter WRITE_DATA = `PARAM_SIZE'd13;
parameter WRITE_DATA_END = `PARAM_SIZE'd14;
parameter UTMI_RESET = `PARAM_SIZE'd15;
parameter READ_DATA_FAIL = `PARAM_SIZE'd16;
parameter FAIL = `PARAM_SIZE'b01010101;

`define REG_MAP_SIZE 6
parameter FUNC_CTRL_REG = `REG_MAP_SIZE'h04;

reg [`PARAM_SIZE - 1 : 0] state, next_state;
reg [7:0] reg_val, rxcmd, usb_data_i_reg, usb_data_o_reg;
reg [5:0] reg_addr;

reg reg_en, reg_rw;
reg usb_data_o_start;

reg last_usb_dir, last_usb_nxt, usb_data_o_get_next, usb_data_i_set_next;

wire [7:0] USB_DATA_I, USB_DATA_O;

wire now_write_a = !USB_DIR & !last_usb_dir;
reg usb_stupid_test;

assign STATE = state;

always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		state <= RESET;
		next_state <= RESET;

		rxcmd <= 8'd0;
		reg_val <= 8'd0;
		reg_addr <= 6'd0;
		reg_en <= 0;
		reg_rw <= 0;

		last_usb_dir <= 1'b0;
		last_usb_nxt <= 1'b0;	

		usb_data_i_reg <= 8'd0;
		usb_data_o_reg <= 0;	

		usb_stupid_test <= 1'b0;
		usb_data_o_get_next <= 0;
		usb_data_i_set_next <= 0;
		usb_data_o_start <= 0;
	end else begin
		last_usb_dir <= USB_DIR;
		last_usb_nxt <= USB_NXT;	

		usb_data_o_get_next <= 0;

		// register operations/usb data write high-tech "scheduling" system
		if (REG_EN && !reg_en) begin
			reg_en <= 1;
			reg_val <= REG_DATA_I;
			reg_addr <= REG_ADDR;
			reg_rw <= REG_RW;
		end

		if (USB_DATA_IN_START_END && !usb_data_o_start) begin
			usb_data_o_reg <= USB_DATA_IN;
			usb_data_o_get_next <= 1;
			usb_data_o_start <= 1;	
		end
		// end of RO/USBWHT"SCH"SYS -----------------------------------

		case (state)
		RESET: begin
			state <= POST_RESET;
		end
		UTMI_RESET: begin
			if (USB_DIR)
				state <= POST_RESET;
		end
		POST_RESET: begin
			if (!last_usb_dir & !USB_DIR) begin
				state <= IDLE;
			end
		end
		IDLE: begin
			usb_stupid_test <= 1'b0;
			usb_data_o_get_next <= 0;

			if (USB_DIR) begin
				state <= READ_DATA;
			end else if (usb_data_o_start) begin
			 	state <= WRITE_DATA_PID;
			end else if (reg_en) begin
				reg_en <= 0;
				case (reg_rw)
				1'b0: begin
					state <= REG_READ;
				end
				1'b1: begin
					state <= REG_WRITE;
					next_state <= IDLE;

					if (reg_addr == 8'h04 && (reg_val & 8'b00100000))
						next_state <= UTMI_RESET;
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
				usb_stupid_test <= 1'b1; //should it really be here?
			end else begin
				state <= READ_DATA;
			end
		end
		REG_WRITE_DATA: begin
			if (!last_usb_dir & !USB_DIR) begin
				if (!USB_NXT) begin //should it really be here?
					state <= REG_WRITE_END;
				end
			end else begin
				state <= READ_DATA;
			end
		end
		REG_WRITE_END: begin
			if (!USB_DIR)
				state <= next_state;
			else
				state <= READ_DATA;
		end
		REG_READ: begin
			if (!last_usb_dir & !USB_DIR) begin
				if (USB_NXT) begin
					state <= REG_READ_DATA;
				end
			end else begin
				state <= REG_READ_END;
			end
		end
		REG_READ_DATA: begin
			if (last_usb_dir) begin
				reg_val <= USB_DATA_I;
				state <= REG_READ_END;
			end else if (!last_usb_dir && !USB_DIR && USB_NXT) begin
				state <= REG_READ_END;
			end
		end
		REG_READ_END: begin
			state <= IDLE;
		end
		WRITE_DATA_PID: begin
			usb_data_o_get_next <= 0;

			if (!last_usb_dir & !USB_DIR) begin
				if (USB_NXT & usb_stupid_test) begin
					usb_data_o_reg <= USB_DATA_IN;
					usb_data_o_get_next <= 1;
					state <= WRITE_DATA;
				end
				usb_stupid_test <= 1'b1;
			end else begin
				state <= READ_DATA; 
			end
		end	
		WRITE_DATA: begin
			usb_data_o_get_next <= 0;

			if (USB_DIR) begin //FAIL
				state <= READ_DATA;
				usb_data_o_start <= 0;
			end else if (USB_DATA_IN_START_END) begin //TODO
				state <= WRITE_DATA_END;
				usb_data_o_start <= 0;
			end else if (USB_NXT) begin
				usb_data_o_reg <= USB_DATA_IN;
				usb_data_o_get_next <= 1;
			end
		end
		/*FAIL: begin
		end*/
		WRITE_DATA_END: begin
			state <= IDLE;
		end
		READ_DATA: begin
			usb_data_i_set_next <= 0;
	
			if (!USB_DIR) begin
				state <= READ_DATA_END;
			end else begin
				if (!USB_NXT) begin
					usb_data_i_reg <= 0;
					rxcmd <= USB_DATA_I;
					if (USB_DATA_I & 8'b00100000)
						state <= READ_DATA_FAIL;
				end else begin
					usb_data_i_reg <= USB_DATA_I;
					usb_data_i_set_next <= 1;		
				end
			end
		end
		READ_DATA_FAIL: begin
			state <= IDLE;
		end
		READ_DATA_END: begin
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

reg USB_DATA_IN_STRB_a, USB_DATA_IN_FAIL_a;
reg USB_DATA_OUT_STRB_a, USB_DATA_OUT_END_a, USB_DATA_OUT_FAIL_a;
reg [7:0] USB_DATA_OUT_a;

always @(NRST_A_USB, state, reg_addr, reg_val, rxcmd, last_usb_nxt, usb_data_i_reg, usb_data_o_reg, usb_data_o_get_next, usb_data_i_set_next) begin
	case (state)
	RESET: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b1;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = 8'd0;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	POST_RESET: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = 8'd0;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	REG_WRITE: begin //Write TXCMD
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b10, reg_addr};

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	REG_WRITE_DATA: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = reg_val;

		REG_DATA_O_a = 8'd0;		
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	REG_WRITE_END: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b1;
		USB_DATA_O_a = reg_val;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b1;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	REG_READ: begin //send TXCMD
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b11, reg_addr};

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	REG_READ_DATA: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b11, reg_addr};

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	REG_READ_END: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = reg_val;
		REG_DONE_a = 1'b1;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	IDLE: begin
		ready_a = 1'b1;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;
	end
	READ_DATA: begin
		ready_a = 1'b1;
	
		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;
		
		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1;
		
		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 1;

		USB_DATA_OUT_STRB_a = usb_data_i_set_next;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = usb_data_i_reg;			
	end
	READ_DATA_FAIL: begin
		ready_a = 1'b1;
	
		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;
		
		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;
		
		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 1;
		USB_DATA_OUT_a = 0;	
	end
	READ_DATA_END: begin
		ready_a = 1'b1;
	
		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;
		
		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;
		
		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 1;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;	
	end
	WRITE_DATA_PID: begin
		ready_a = 1'b1;
	
		USB_STP_a = 1'b0;
		USB_DATA_O_a = {2'b01, usb_data_o_reg[5:0]};
		
		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;
		
		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = usb_data_o_get_next;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;	
	end
	WRITE_DATA: begin
		ready_a = 1'b1;
	
		USB_STP_a = 1'b0;
		USB_DATA_O_a = usb_data_o_reg;
		
		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;
		
		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = usb_data_o_get_next;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;	
	end
	WRITE_DATA_END: begin
		ready_a = 1'b1;
	
		USB_STP_a = 1'b1;
		USB_DATA_O_a = 8'd0;
		
		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;
		
		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;	
	end
	UTMI_RESET: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;	
	end
	default: begin
		ready_a = 1'b0;

		USB_STP_a = 1'b0;
		USB_DATA_O_a = 8'd0;

		REG_DATA_O_a = 8'd0;
		REG_DONE_a = 1'b0;
		REG_FAIL_a = 1'b0;

		RXCMD_a = rxcmd;

		USB_DATA_IN_STRB_a = 0;
		USB_DATA_IN_FAIL_a = 0;

		USB_DATA_OUT_STRB_a = 0;
		USB_DATA_OUT_END_a = 0;
		USB_DATA_OUT_FAIL_a = 0;
		USB_DATA_OUT_a = 0;	
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

assign USB_DATA_IN_STRB = USB_DATA_IN_STRB_a;
assign USB_DATA_IN_FAIL = USB_DATA_IN_FAIL_a;
assign USB_DATA_OUT_STRB = USB_DATA_OUT_STRB_a;
assign USB_DATA_OUT_END = USB_DATA_OUT_END_a;
assign USB_DATA_OUT_FAIL = USB_DATA_OUT_FAIL_a;
assign USB_DATA_OUT = USB_DATA_OUT_a;

assign USB_DATA_I = USB_DATA;
assign USB_DATA = (now_write_a == 1'b1) ? USB_DATA_O : 8'hzz;

endmodule
