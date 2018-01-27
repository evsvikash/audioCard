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
parameter R_FUN_CTRL_REG = `PARAM_SIZE'd3;
//parameter W_OTG_CTRL_REG = `PARAM_SIZE'd4;
parameter R_OTG_CTRL_REG = `PARAM_SIZE'd5;
//parameter W_SCR_REG  = `PARAM_SIZE'd6;
//parameter R_SCR_REG  = `PARAM_SIZE'd7;
parameter WAIT_RD = `PARAM_SIZE'd8;
parameter WAIT_WR = `PARAM_SIZE'd9;
parameter IDLE = `PARAM_SIZE'd10;

`define REG_MAP_SIZE 6
parameter FUN_CTRL_REG = `REG_MAP_SIZE'h04;
parameter OTG_CTRL_REG  = `REG_MAP_SIZE'h0A;
parameter SCRATCH_REG   = `REG_MAP_SIZE'h16;


reg [`PARAM_SIZE - 1 : 0] state;
reg [7 : 0] ulpi_reg_data_o, ulpi_rxcmd_o;
//reg [20:0] cnt;
reg [8:0] cnt;
reg[7:0] small_cnt;
reg only_once;

//k-state - send 0; j-state - send 1 only

always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin

		state <= RESET;

		ulpi_reg_data_o <= 0;
		ulpi_rxcmd_o <= 0;
		cnt <= 0;
		small_cnt <= 0;
		only_once <= 0;

	end else begin

		ulpi_rxcmd_o <= ulpi_rxcmd_a;
	
		if (ulpi_ready_a) begin
	
			case (state)
			RESET: begin
				state <= IDLE;
			end
			IDLE: begin
				cnt <= cnt + 1;
				if (cnt == 1) begin
					state <= R_FUN_CTRL_REG;
				end else if (cnt == 450) begin
					state <= W_FUN_CTRL_REG;
				end else if (cnt == 256) begin
					state <= R_OTG_CTRL_REG;
/*				end else if (cnt == 3072) begin
					state <= W_SCR_REG;
					small_cnt <= small_cnt + 1;
			/*	end else if (cnt == 4096) begin
					state <= W_FUN_CTRL_REG;*/
/*				end else if (cnt == 8192) begin
					state <= R_SCR_REG;*/
				end
			end
/*			W_OTG_CTRL_REG: begin
				state <= WAIT_WR; 
			end*/
			R_OTG_CTRL_REG: begin
				state <= WAIT_RD;
			end
			W_FUN_CTRL_REG: begin
				state <= WAIT_WR;
			end
			R_FUN_CTRL_REG: begin
				state <= WAIT_RD;
			end
/*			W_SCR_REG: begin
				state <= WAIT_WR;
			end
			R_SCR_REG: begin
				state <= WAIT_RD;
			end*/
			WAIT_WR: begin
				if (ulpi_reg_done_a) begin
					state <= IDLE;
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

always @(state/*, small_cnt*/) begin
	case (state)
	RESET: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;
	end
	IDLE: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;
	end
	W_FUN_CTRL_REG: begin // <-- can not write this register
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = 8'b01000110;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;
	end
	R_FUN_CTRL_REG: begin
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;
	end
/*	W_OTG_CTRL_REG: begin
		ulpi_reg_addr_a = OTG_CTRL_REG;
		ulpi_reg_data_i_a = 8'b00000110;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1; 
	end*/
	R_OTG_CTRL_REG: begin
		ulpi_reg_addr_a = OTG_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1; 
	end
/*	W_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = small_cnt;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;
	end
	R_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;
	end*/
	WAIT_WR: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;
	end
	WAIT_RD: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;	
	end
	default: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;	
	end
	endcase
end

assign LED = ~ulpi_rxcmd_o;

endmodule
