/*
	What is this?
	
	This module is supposed to pass packets between ULPI and endpoints, and
	is responsible for a speed handshake.

	Is it generic?

	Lol no, it is specially written for USB 2.0 slave device 480MB/s (or 
	480 Mb/s, I don't care).
*/
module usb_handshake_multiplexer (
	input	NRST,

	input	USB_CLKIN,     		//Phy OUTPUT 60Mhz Clock 
	output	USB_CS,			//USB PHY select (1 - phy selected)
	inout	[7:0] USB_DATA,
	input	USB_DIR,
	input	USB_NXT,
	output	USB_RESETN,		//Reset PHY
	output	USB_STP,

	inout [7:0] LED,
	
	output clk_10MHz_o,

	output [23:0] token_0,
	output token_0_strb,
	output [7:0] data_o_0,
	output data_o_strb_0,
	output data_o_end_0,
	output data_o_fail_0,
	output [7:0] pid_o,

	input [7:0] data_i_0,
	input data_i_start_stop_0,
	output data_i_strb_0,
	output data_i_fail_0
);

 //Clock wires
wire CLK_60M;

//NRST wire
wire NRST_A_USB;

assign CLK_60M = USB_CLKIN;
assign NRST_A_USB = NRST;

wire [7:0] ulpi_reg_data_o_a;
reg [7:0] ulpi_reg_data_i_a;
reg [5:0] ulpi_reg_addr_a;
wire [7:0] ulpi_rxcmd_a;
wire ulpi_ready_a, ulpi_reg_done_a, ulpi_reg_fail_a;
reg ulpi_reg_rw_a, ulpi_reg_en_a;

reg [7:0] ulpi_usb_data_i_a;
reg ulpi_usb_data_i_start_end_a;
wire ulpi_usb_data_i_strb_a, ulpi_usb_data_i_fail_a;

wire [7:0] ulpi_usb_data_o_a;
wire ulpi_usb_data_o_strb_a, ulpi_usb_data_o_end_a, ulpi_usb_data_o_fail_a;

wire[7:0] ulpi_state;

reg token_0_strb_a, data_o_strb_0_a, data_o_end_0_a, data_o_fail_0_a;
reg [7:0] data_o_0_a;
reg [23:0] token_0_a;

reg data_i_strb_0_a, data_i_fail_0_a;

assign token_0 = token_0_a;
assign token_0_strb = token_0_strb_a;
assign data_o_0 = data_o_0_a;
assign data_o_strb_0 = data_o_strb_0_a;
assign data_o_end_0 = data_o_end_0_a;
assign data_o_fail_0 = data_o_fail_0_a;
assign data_i_strb_0 = data_i_strb_0_a;
assign data_i_fail_0 = data_i_fail_0_a;

ULPI ULPI_0 (
	.CLK_60M(CLK_60M),
	.NRST_A_USB(NRST_A_USB),
	.USB_DATA(USB_DATA),
	.USB_DIR(USB_DIR),
	.USB_NXT(USB_NXT),
	.USB_RESETN(USB_RESETN),
	.USB_STP(USB_STP),
	.USB_CS(USB_CS),
	.REG_RW(ulpi_reg_rw_a),
	.REG_EN(ulpi_reg_en_a),
	.REG_ADDR(ulpi_reg_addr_a),
	.REG_DATA_I(ulpi_reg_data_i_a),
	.REG_DATA_O(ulpi_reg_data_o_a),
	.REG_DONE(ulpi_reg_done_a),
	.REG_FAIL(ulpi_reg_fail_a),
	.RXCMD(ulpi_rxcmd_a),
	.READY(ulpi_ready_a),
	.USB_DATA_IN(ulpi_usb_data_i_a),
	.USB_DATA_IN_STRB(ulpi_usb_data_i_strb_a),
	.USB_DATA_IN_START_END(ulpi_usb_data_i_start_end_a),
	.USB_DATA_IN_FAIL(ulpi_usb_data_i_fail_a),
	.USB_DATA_OUT(ulpi_usb_data_o_a),
	.USB_DATA_OUT_STRB(ulpi_usb_data_o_strb_a),
	.USB_DATA_OUT_END(ulpi_usb_data_o_end_a),
	.USB_DATA_OUT_FAIL(ulpi_usb_data_o_fail_a),
	.STATE(ulpi_state)
);

//-----------------------------------------------------------------------------
`define PARAM_SIZE 8
parameter RESET = `PARAM_SIZE'd0;
parameter W_FUN_CTRL_REG = `PARAM_SIZE'd2;
//parameter R_FUN_CTRL_REG = `PARAM_SIZE'd3;
parameter W_OTG_CTRL_REG = `PARAM_SIZE'd4;
//parameter R_OTG_CTRL_REG = `PARAM_SIZE'd5;
parameter W_SCR_REG  = `PARAM_SIZE'd6;
parameter R_SCR_REG  = `PARAM_SIZE'd7;
parameter WAIT_RD = `PARAM_SIZE'd8;
parameter WAIT_WR = `PARAM_SIZE'd9;
parameter IDLE = `PARAM_SIZE'd10;
parameter DETECT_SE0 = `PARAM_SIZE'd11;
parameter TXCMD_CHIRP_K = `PARAM_SIZE'd12;
parameter TXCMD_CHIRP_K_START = `PARAM_SIZE'd13;
parameter TXCMD_CHIRP_K_END = `PARAM_SIZE'd14;
parameter DETECT_K = `PARAM_SIZE'd15;
parameter DETECT_J = `PARAM_SIZE'd16;
parameter SET_ULPI_START = `PARAM_SIZE'd17;
parameter SET_ULPI_CHIRP = `PARAM_SIZE'd18;
parameter SET_ULPI_HS_IDLE = `PARAM_SIZE'd19;
parameter SETUP_TOKEN = `PARAM_SIZE'd22;
parameter SEND_TOKEN = `PARAM_SIZE'd23;
parameter SEND_DATA_TO_EP = `PARAM_SIZE'd24;
parameter SEND_DATA_TO_ULPI = `PARAM_SIZE'd25;
parameter SEND_DATA_TO_ULPI_START = `PARAM_SIZE'd26;
parameter SEND_DATA_TO_ULPI_END = `PARAM_SIZE'd27;
parameter FAIL = `PARAM_SIZE'b01010101;

`define REG_MAP_SIZE 6
parameter FUN_CTRL_REG = `REG_MAP_SIZE'h04;
parameter OTG_CTRL_REG  = `REG_MAP_SIZE'h0A;
parameter SCRATCH_REG   = `REG_MAP_SIZE'h16;

parameter PID_OUT = 8'b11100001;
parameter PID_IN  = 8'b01101001;
parameter PID_SOF = 8'b10100101;
parameter PID_SETUP = 8'b00101101;
parameter PID_DATA0 = 8'b11000011;
parameter PID_DATA1 = 8'b01001011;
parameter PID_DATA2 = 8'b10000111;
parameter PID_MDATA = 8'b00001111;
parameter PID_ACK = 8'b11010010;
parameter PID_NAK = 8'b01011010;
parameter PID_STALL = 8'b00011110;
parameter PID_NYET = 8'b10010110;
parameter PID_PING = 8'b10110100;

reg [`PARAM_SIZE - 1 : 0] state, next_state, previous_state;
reg [7 : 0] ulpi_reg_data_o, ulpi_rxcmd_o, fun_ctrl_reg_val;
reg [1:0] cnt;
reg [1:0] jk_trans;
reg [1:0] token_part;
reg [23:0] token;
reg selected_EP;

reg clk_10MHz, nrst_clk_10MHz_cnt;
reg [15:0] clk_10MHz_cnt;
reg [7:0] pid;

assign clk_10MHz_o = clk_10MHz;

assign pid_o = pid;

//k-state - send 0; j-state - send 1 only

// This a high-tech clock generator
// create 10[MHz] clock == 0.1[us]
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		cnt <= 0;
		clk_10MHz <= 0;
	end else begin
		cnt <= cnt + 1;
		if (cnt == 2) begin
			cnt <= 0;
			clk_10MHz <= !clk_10MHz;
		end		
	end
end

// This is high-tech counter
always @(posedge clk_10MHz, negedge nrst_clk_10MHz_cnt) begin
	if (!nrst_clk_10MHz_cnt) begin
		clk_10MHz_cnt <= 0;
	end else begin
		clk_10MHz_cnt <= clk_10MHz_cnt + 1;
	end
end

reg [7:0] led_val;
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin

		state <= RESET;
		next_state <= RESET;
		previous_state <= RESET;

		ulpi_reg_data_o <= 0;
		ulpi_rxcmd_o <= 0;
		fun_ctrl_reg_val <= 0;

		jk_trans <= 0;

		nrst_clk_10MHz_cnt <= 0;

		token <= 0;
		token_part <= 0;
	
		selected_EP <= 0;

		led_val <= 0;

		pid <= 0;
	end else begin

		nrst_clk_10MHz_cnt <= 1;
		ulpi_rxcmd_o <= ulpi_rxcmd_a;
	
		case (state)
		RESET: begin
			if (ulpi_ready_a) begin
				state <= W_OTG_CTRL_REG;
				next_state <= SET_ULPI_START;
				previous_state <= W_OTG_CTRL_REG;
				nrst_clk_10MHz_cnt <= 0;
			end
		end
		SET_ULPI_START : begin
//			if (clk_10MHz_cnt >= 65000) begin //Why? I don't remember, but if it works, leave it.
				fun_ctrl_reg_val <= 8'b01100101;
				state <= W_FUN_CTRL_REG;
				next_state <= DETECT_SE0;
				previous_state <= SET_ULPI_START;
//			end
		end	
		DETECT_SE0: begin
			if (ulpi_rxcmd_o[1:0] != 2'b00 || !ulpi_ready_a) begin
				nrst_clk_10MHz_cnt <= 0; 
			end else if (clk_10MHz_cnt >= 25) begin
				state <= SET_ULPI_CHIRP;
			end
		end
		SET_ULPI_CHIRP: begin
			fun_ctrl_reg_val <= 8'b01010100;
			state <= W_FUN_CTRL_REG;
			next_state <= TXCMD_CHIRP_K_START;
			previous_state <= SET_ULPI_CHIRP;
		end
		TXCMD_CHIRP_K_START: begin
			nrst_clk_10MHz_cnt <= 0;
			state <= TXCMD_CHIRP_K;
		end	
		TXCMD_CHIRP_K: begin
			if (clk_10MHz_cnt > 20000)
				state <= TXCMD_CHIRP_K_END;
			if (ulpi_usb_data_i_fail_a)
				state <= FAIL;
		end
		TXCMD_CHIRP_K_END: begin
			nrst_clk_10MHz_cnt <= 0;
			state <= DETECT_K; //now we will be detecting K-J-K-J-L-J sequence
		end
		DETECT_K: begin
			if (ulpi_rxcmd_o[1:0] == 2'b10) begin
				if (clk_10MHz_cnt > 30) begin
					nrst_clk_10MHz_cnt <= 0;
					state <= DETECT_J;
				end
			end else begin
				nrst_clk_10MHz_cnt <= 0;
			end
		end
		DETECT_J: begin
			if (ulpi_rxcmd_o[1:0] == 2'b01) begin
				if (clk_10MHz_cnt > 30) begin
					if (jk_trans == 2) begin
						state <= SET_ULPI_HS_IDLE;		
					end else begin
						nrst_clk_10MHz_cnt <= 0;
						state <= DETECT_K;
						jk_trans <= jk_trans + 1;
					end
				end
			end else begin
				nrst_clk_10MHz_cnt <= 0;
			end
		end
		SET_ULPI_HS_IDLE: begin
			fun_ctrl_reg_val <= 8'b01000000;
			state <= W_FUN_CTRL_REG;
			next_state <= IDLE;
			previous_state <= SET_ULPI_HS_IDLE;
		end
		W_OTG_CTRL_REG: begin
			state <= WAIT_WR; 
		end
/*		R_OTG_CTRL_REG: begin
			state <= WAIT_RD;
		end*/
		W_FUN_CTRL_REG: begin
			state <= WAIT_WR;
		end
/*		R_FUN_CTRL_REG: begin
			state <= WAIT_RD;
		end*/
/*		W_SCR_REG: begin
			state <= IDLE;
		end*/
/*		R_SCR_REG: begin
			state <= WAIT_RD;
		end*/
		IDLE: begin
			if (ulpi_usb_data_o_strb_a) begin
				led_val <= 8'b01010101;
				if (ulpi_usb_data_o_a == PID_SETUP) begin
					state <= SETUP_TOKEN;
					token[23:8] <= 0;
					/* it should be moved to SETUP_TOKEN state...
				 	   But ULPI code is already written, so for a sake
					   of time, I am leaveing it here.
					*/
					token[7:0] <= ulpi_usb_data_o_a;
					token_part <= 1;
				end else if (ulpi_usb_data_o_a == PID_DATA0 || 
					     ulpi_usb_data_o_a == PID_DATA1) begin
					state <= SEND_DATA_TO_EP;
					pid <= ulpi_usb_data_o_a;
				end	
			end else if (data_i_start_stop_0) begin
				state <= SEND_DATA_TO_ULPI_START; 
			end
		end
		SETUP_TOKEN: begin
			if (ulpi_usb_data_o_fail_a) begin
				state <= IDLE;
			end else begin
				case(token_part)
				2'd1: begin
					if (ulpi_usb_data_o_strb_a) begin
						token[15:8] <= ulpi_usb_data_o_a;
						token_part <= 2;
					end
				end
				2'd2: begin
					if (ulpi_usb_data_o_strb_a) begin
						token[23:16] <= ulpi_usb_data_o_a;
						token_part <= 0;
						selected_EP <= token[15];
						state <= SEND_TOKEN;
					end
				end
				default: begin
					state <= IDLE;
				end
				endcase
			end
		end
		SEND_TOKEN: begin
			if (ulpi_usb_data_o_end_a || ulpi_usb_data_o_fail_a)
				state <= IDLE;
		end
		SEND_DATA_TO_EP: begin
			if (ulpi_usb_data_o_end_a || ulpi_usb_data_o_fail_a) begin 
				state <= IDLE;			
			end
		end
		SEND_DATA_TO_ULPI_START: begin
			state <= SEND_DATA_TO_ULPI;
		end
		SEND_DATA_TO_ULPI: begin
			if (data_i_start_stop_0) begin
				state <= IDLE;
			end else if (ulpi_usb_data_i_fail_a) begin
				state <= IDLE;
			end 
		end
		FAIL: begin
		end
		WAIT_WR: begin
			nrst_clk_10MHz_cnt <= 0; //not the best place
			if (ulpi_reg_done_a) begin
				state <= next_state;
			end else if (ulpi_reg_fail_a) begin
				state <= previous_state;
			end
		end
	/*	WAIT_RD: begin
			if (ulpi_reg_done_a) begin
				state <= IDLE;
				ulpi_reg_data_o <= ulpi_reg_data_o_a;
			end else if (ulpi_reg_fail_a) begin
				state <= IDLE;
			end
		end*/
		default: begin
			state <= RESET;
		end
		endcase
	end
end

always @(state, fun_ctrl_reg_val, token, selected_EP, ulpi_usb_data_o_a, ulpi_usb_data_o_strb_a, ulpi_usb_data_o_end_a, ulpi_usb_data_o_fail_a, data_i_0, ulpi_usb_data_i_strb_a, ulpi_usb_data_i_fail_a) begin
	case (state)
	RESET: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
		
		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	DETECT_SE0: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	TXCMD_CHIRP_K: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	TXCMD_CHIRP_K_START: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 1;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	TXCMD_CHIRP_K_END: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 1;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	IDLE: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	W_FUN_CTRL_REG: begin
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = fun_ctrl_reg_val;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
/*	R_FUN_CTRL_REG: begin
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;
	end*/
	W_OTG_CTRL_REG: begin
		ulpi_reg_addr_a = OTG_CTRL_REG;
		ulpi_reg_data_i_a = 8'b00000000;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1; 

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	DETECT_K: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	DETECT_J: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
/*	R_OTG_CTRL_REG: begin
		ulpi_reg_addr_a = OTG_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;

 		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end */
	/*W_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'b01010101;
		ulpi_reg_rw_a = 0;
		ulpi_reg_en_a = 0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end*/
	/*R_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end*/
	WAIT_WR: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	SET_ULPI_CHIRP: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end	
	SET_ULPI_START: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
/*	WAIT_RD: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end*/
	SET_ULPI_HS_IDLE: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	FAIL: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	SETUP_TOKEN: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	SEND_TOKEN: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
		
		if (!selected_EP) begin
			token_0_a = token;
			token_0_strb_a = 1;
		end else begin
			token_0_a = 0;
			token_0_strb_a = 0;
		end

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	SEND_DATA_TO_EP: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		if (!selected_EP) begin
			data_o_0_a = ulpi_usb_data_o_a;
			data_o_strb_0_a = ulpi_usb_data_o_strb_a;
			data_o_end_0_a = ulpi_usb_data_o_end_a;
			data_o_fail_0_a = ulpi_usb_data_o_fail_a;
		end else begin
			data_o_0_a = 0;
			data_o_strb_0_a = 0;
			data_o_end_0_a = 0;
			data_o_fail_0_a = 0;	
		end

		data_i_strb_0_a = 0; 
		data_i_fail_0_a = 0;
	end
	SEND_DATA_TO_ULPI_START: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = data_i_0;
		ulpi_usb_data_i_start_end_a = 1;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = ulpi_usb_data_i_strb_a; 
		data_i_fail_0_a = ulpi_usb_data_i_fail_a;
	end
	SEND_DATA_TO_ULPI: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = data_i_0;
		ulpi_usb_data_i_start_end_a = data_i_start_stop_0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;

		data_i_strb_0_a = ulpi_usb_data_i_strb_a; 
		data_i_fail_0_a = ulpi_usb_data_i_fail_a;
	end
	default: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;	

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;

		token_0_a = 0;
		token_0_strb_a = 0;

		data_o_0_a = 0;
		data_o_strb_0_a = 0;
		data_o_end_0_a = 0;
		data_o_fail_0_a = 0;
	
		data_i_strb_0_a = 0;
		data_i_fail_0_a = 0;
	end
	endcase
end

assign LED = led_val;

endmodule
