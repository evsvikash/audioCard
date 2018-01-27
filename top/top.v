module top (
	input	NRST,

	input	USB_CLKIN,     		//Phy OUTPUT 60Mhz Clock 
	output	USB_CS,			//USB PHY select (1 - phy selected)
	inout	[7:0] USB_DATA,
	input	USB_DIR,
	input	USB_NXT,
	output	USB_RESETN,		//Reset PHY
	output	USB_STP,

	inout [7:0] LED
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
	.USB_DATA_OUT_FAIL(ulpi_usb_data_o_fail_a)
);

//-----------------------------------------------------------------------------
`define PARAM_SIZE 8
parameter RESET = `PARAM_SIZE'd0;
parameter W_FUN_CTRL_REG = `PARAM_SIZE'd2;
//parameter R_FUN_CTRL_REG = `PARAM_SIZE'd3;
parameter W_OTG_CTRL_REG = `PARAM_SIZE'd4;
//parameter R_OTG_CTRL_REG = `PARAM_SIZE'd5;
//parameter W_SCR_REG  = `PARAM_SIZE'd6;
//parameter R_SCR_REG  = `PARAM_SIZE'd7;
parameter WAIT_RD = `PARAM_SIZE'd8;
parameter WAIT_WR = `PARAM_SIZE'd9;
parameter IDLE = `PARAM_SIZE'd10;
parameter DETECT_SE0 = `PARAM_SIZE'd11;
parameter TXCMD_CHIRP_K = `PARAM_SIZE'd12;
parameter TXCMD_CHIRP_K_START = `PARAM_SIZE'd13;
parameter TXCMD_CHIRP_K_END = `PARAM_SIZE'd14;

`define REG_MAP_SIZE 6
parameter FUN_CTRL_REG = `REG_MAP_SIZE'h04;
parameter OTG_CTRL_REG  = `REG_MAP_SIZE'h0A;
parameter SCRATCH_REG   = `REG_MAP_SIZE'h16;


reg [`PARAM_SIZE - 1 : 0] state, next_state;
reg [7 : 0] ulpi_reg_data_o, ulpi_rxcmd_o;
reg [1:0] cnt;

reg clk_10MHz;
reg [15:0] clk_10MHz_cnt;

//k-state - send 0; j-state - send 1 only
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin

		state <= RESET;
		next_state <= RESET;

		ulpi_reg_data_o <= 0;
		ulpi_rxcmd_o <= 0;
		cnt <= 0;
		clk_10MHz <= 0;
		clk_10MHz_cnt <= 0;
	end else begin

		ulpi_rxcmd_o <= ulpi_rxcmd_a;

// create 10[MHz] clock == 0.1[us]
//-----------------------------------------------------------------------------	
		cnt <= cnt + 1;
		if (cnt == 3) begin
			cnt <= 1;
			clk_10MHz <= !clk_10MHz;
			if (!clk_10MHz)
				clk_10MHz_cnt <= clk_10MHz_cnt + 1;
		end		
//-----------------------------------------------------------------------------	

		if (ulpi_ready_a) begin
	
			case (state)
			RESET: begin
				state <= W_OTG_CTRL_REG;
				next_state <= DETECT_SE0;
			end
			DETECT_SE0: begin
				//we should clk_10MHz_cnt reset here, not in WAIT_WR...
				if (ulpi_rxcmd_o[1:0] != 2'b00) begin
					clk_10MHz_cnt <= 0; 
				end else if (clk_10MHz_cnt > 25) begin
					state <= W_FUN_CTRL_REG;
					next_state <= TXCMD_CHIRP_K_START;
				end
			end
			TXCMD_CHIRP_K_START: begin
				clk_10MHz_cnt <= 0;
				state <= TXCMD_CHIRP_K;
			end	
			TXCMD_CHIRP_K: begin
				if (clk_10MHz_cnt > 20000)
					state <= TXCMD_CHIRP_K_END;
			end
			TXCMD_CHIRP_K_END: begin
				state <= IDLE;
			end
			W_OTG_CTRL_REG: begin
				state <= WAIT_WR; 
			end
/*			R_OTG_CTRL_REG: begin
				state <= WAIT_RD;
			end*/
			W_FUN_CTRL_REG: begin
				state <= WAIT_WR;
			end
/*			R_FUN_CTRL_REG: begin
				state <= WAIT_RD;
			end*/
/*			W_SCR_REG: begin
				state <= WAIT_WR;
			end
			R_SCR_REG: begin
				state <= WAIT_RD;
			end*/
			IDLE: begin
			end
			WAIT_WR: begin
				clk_10MHz_cnt <= 0; //not the best place
				if (ulpi_reg_done_a) begin
					state <= next_state;
				end else if (ulpi_reg_fail_a) begin
					state <= IDLE;
				end
			end
			WAIT_RD: begin
				if (ulpi_reg_done_a) begin
					state <= IDLE;
					ulpi_reg_data_o <= ulpi_reg_data_o_a;
				end else if (ulpi_reg_fail_a) begin
					state <= IDLE;
				end
			end
			default: begin
				state <= RESET;
			end
			endcase
		end
	end
end

always @(state) begin
	case (state)
	RESET: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	DETECT_SE0: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	TXCMD_CHIRP_K: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	TXCMD_CHIRP_K_START: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 1;	
	end
	TXCMD_CHIRP_K_END: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 1;
	end
	IDLE: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	W_FUN_CTRL_REG: begin // <-- can not write this register
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = 8'b01010100;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
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
	end
/*	R_OTG_CTRL_REG: begin
		ulpi_reg_addr_a = OTG_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;

 		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end */
/*	W_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'b01010101;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	R_SCR_REG: begin
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
	end
	WAIT_RD: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	default: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;	

		ulpi_usb_data_i_a = 0;
		ulpi_usb_data_i_start_end_a = 0;
	end
	endcase
end

assign LED = ~state;

endmodule
