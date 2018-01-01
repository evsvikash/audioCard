`include "../usb_core/rtl/usbf_defines.v"

module top (
	input	CLK,		//AT LEAST 60MHz (is 50MHz, but PLL multiplies it)
	input	NRST,

	input	USB_CLKIN,     		//Phy OUTPUT 60Mhz Clock 
	output	USB_CS,			//USB PHY select (1 - phy selected)
	inout	[7:0] USB_DATA,
	input	USB_DIR,
	input	USB_FAULTN,			//set to 0 when overcurrent or reverse-voltage condition
	input	USB_NXT,
	output	USB_RESETN,		//Reset PHY
	output	USB_STP,

	output [7:0] LED
);


//Clock wires
wire CLK_100M, CLK_PLL_LOCKED, CLK_50M, CLK_60M;

//NRST registers
reg NRST_CLK_100M, NRST_A_USB, NRST_CLK_60M;

//LED registers
reg [7:0] LED_internal;

BUFG BUFG_0 (
	.inclk(CLK),
	.outclk(CLK_50M)
);
BUFG BUFG_1 (
	.inclk(USB_CLKIN),
	.outclk(CLK_60M)
);


clk_pll_100M clk_pll_100M_0 (
	.areset(1'b0),
	.inclk0(CLK_50M),
	.c0(CLK_100M),
	.locked(CLK_PLL_LOCKED)
);



wire [7:0] ulpi_led;
wire [7:0] ulpi_reg_data_o_a;
reg [7:0] ulpi_reg_data_i_a;
reg [5:0] ulpi_reg_addr_a;
wire [7:0] ulpi_rxcmd_a;
wire ulpi_ready_a, ulpi_reg_done_a, ulpi_reg_fail_a;
reg ulpi_reg_rw_a, ulpi_reg_en_a;

ULPI ULPI_0 (
	.CLK_60M(CLK_60M),
	.NRST_A_USB(NRST_A_USB),
	.USB_DATA(USB_DATA),
	.USB_DIR(USB_DIR),
	.USB_FAULTN(USB_FAULTN),
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

	.LED(ulpi_led)
);

//-----------------------------------------------------------------------------
`define PARAM_SIZE 8
parameter RESET = `PARAM_SIZE'd1;
parameter W_FUN_CTRL = `PARAM_SIZE'd2;
parameter R_FUN_CTRL = `PARAM_SIZE'd3;
parameter W_OTG_CTRL = `PARAM_SIZE'd4;
parameter R_OTG_CTRL = `PARAM_SIZE'd5;
parameter W_SCR_REG  = `PARAM_SIZE'd6;
parameter R_SCR_REG  = `PARAM_SIZE'd7;
parameter WAIT_RD = `PARAM_SIZE'd8;
parameter WAIT_WR = `PARAM_SIZE'd9;
parameter IDLE = `PARAM_SIZE'd10;

`define REG_MAP_SIZE 6
parameter FUNC_CTRL_REG = `REG_MAP_SIZE'h04;
parameter OTG_CTRL_REG  = `REG_MAP_SIZE'h0A;
parameter SCRATCH_REG   = `REG_MAP_SIZE'h16;

reg [`PARAM_SIZE - 1 : 0] state;
reg [7 : 0] ulpi_reg_data_o, ulpi_rxcmd_o;
reg scratch_wr_rd;
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin

		state <= RESET;
		ulpi_reg_data_o <= 8'd0;
		ulpi_rxcmd_o <= 8'd0;
		scratch_wr_rd <= 1'd0;

	end else begin

		ulpi_rxcmd_o <= ulpi_rxcmd_a;
	
		if (!ulpi_ready_a) begin
			state <= RESET;
		end else begin
	
			case (state)
			RESET: begin
				state <= IDLE;
			end
			IDLE: begin
				scratch_wr_rd <= !scratch_wr_rd;
				if (scratch_wr_rd)
					state <= W_SCR_REG;
				else if (!scratch_wr_rd)
					state <= R_SCR_REG;
			end
			W_SCR_REG: begin
				state <= WAIT_WR;
			end
			R_SCR_REG: begin
				state <= WAIT_RD;
			end
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

always @(state) begin
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
	W_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'b10101010;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;
	end
	R_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;
	end
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

/*
Peripheral Low Speed:
XcvrSelect: 10b - FUNC_CTRL
TermSelect: 1b - FUNC_CTRL
OpMode: 00b - FUNC_CTRL
DpPulldown: 0b
DmPulldown: 0b
*/
reg [21:0] cnt;
reg testVal;
always @(posedge CLK_60M,  negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		cnt <= 22'd0;
		testVal <= 1'b0;
	end else begin
		cnt <= cnt + 1;
		if (!cnt) begin
			testVal <= !testVal;
		end
	end
end

reg [25:0] cnt2;
reg [1:0] testVal2;

assign LED = LED_internal;
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		cnt2 <= 26'd0;
		testVal2 <= 2'd0;
		LED_internal <= 8'd0;
	end else begin

		cnt2 <= cnt2 + 1;
		if (!cnt2) begin
			testVal2 <= testVal2 + 1;
		end
		if (testVal2 == 0) begin
			LED_internal <= { ~state[5:0], USB_DIR, testVal};
		end else if (testVal2 == 1) begin
			LED_internal <= ~ulpi_rxcmd_o;
		end else if (testVal2 == 2) begin
			LED_internal <= ~ulpi_led;
		end else begin
			LED_internal <= ~ulpi_reg_data_o;
		end
	
	end
end

/*always @(state, ulpi_reg_data_o_reg, ulpi_reg_done_reg, ulpi_reg_fail_reg, ulpi_rxcmd_reg, ulpi_ready_reg, last_state, next_state, reg_output, cnt, cnt2[7:0]) begin
	state_tmp = state;
	ulpi_reg_rw_tmp = 1'b0;
	ulpi_reg_en_tmp = 1'b0;
	last_state_tmp = last_state;	
	next_state_tmp = next_state;
	ulpi_reg_addr_tmp = 6'd0;
	ulpi_reg_data_i_tmp = 8'd0;
	
	reg_output_tmp = reg_output;

	case (state)
	RESET: begin
		if (ulpi_ready_reg)
			state_tmp = W_SCR_REG;
	end
	W_FUN_CTRL: begin
		ulpi_reg_addr_tmp = FUNC_CTRL_REG;
		ulpi_reg_data_i_tmp = 8'b01000001;

		ulpi_reg_rw_tmp = 1'b1;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT_WR;
		last_state_tmp = W_FUN_CTRL;
		next_state_tmp = W_OTG_CTRL;
	end
	W_OTG_CTRL: begin
		ulpi_reg_addr_tmp = OTG_CTRL_REG;
		ulpi_reg_data_i_tmp = 8'b00000110;

		ulpi_reg_rw_tmp = 1'b1;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT_WR;
		last_state_tmp = W_OTG_CTRL;
		next_state_tmp = R_OTG_CTRL;
	end
	R_FUN_CTRL: begin
		ulpi_reg_addr_tmp = FUNC_CTRL_REG;

		ulpi_reg_rw_tmp = 1'b0;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT_RD;
		last_state_tmp = R_FUN_CTRL;
		next_state_tmp = IDLE;	
	end
	R_OTG_CTRL: begin
		ulpi_reg_addr_tmp = OTG_CTRL_REG;

		ulpi_reg_rw_tmp = 1'b0;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT_RD;
		last_state_tmp = R_OTG_CTRL;
		next_state_tmp = R_SCR_REG;		
	end
	W_SCR_REG: begin
		ulpi_reg_addr_tmp = SCRATCH_REG;
		ulpi_reg_data_i_tmp = 8'b10100101;

		ulpi_reg_rw_tmp = 1'b1;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT_WR;
		last_state_tmp = W_SCR_REG;
		next_state_tmp = R_SCR_REG;
	end
	R_SCR_REG: begin
		ulpi_reg_addr_tmp = SCRATCH_REG;

		ulpi_reg_rw_tmp = 1'b0;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT_RD;
		last_state_tmp = R_SCR_REG;
		next_state_tmp = IDLE;		
	end
	WAIT_WR: begin
		if (ulpi_reg_done_reg) begin
			state_tmp = next_state;
		end else if (ulpi_reg_fail_reg) begin
			state_tmp = last_state;
		end
	end
	WAIT_RD: begin
		if (ulpi_reg_done_reg) begin
			state_tmp = next_state;
			reg_output_tmp = ulpi_reg_data_o_reg;
		end else if (ulpi_reg_fail_reg) begin
			state_tmp = last_state;
		end
	end
	IDLE: begin
		state_tmp = W_SCR_REG;
	end
	default: begin
		state_tmp = RESET;
	end
	endcase
end*/

//-----------------------------------------------------------------------------
always @(posedge CLK_100M, negedge NRST) begin
	if (!NRST) begin

		NRST_A_USB <= 1'b0;
		NRST_CLK_100M <= 1'b0;

	end else begin

		NRST_CLK_100M <= 1'b1;
		NRST_A_USB <= 1'b1;
	
	end
end

endmodule
