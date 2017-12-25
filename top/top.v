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
reg NRST_CLK_100M, NRST_A_USB;

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

reg ulpi_reg_rw_tmp;
reg ulpi_reg_en_tmp;
reg [5:0] ulpi_reg_addr_tmp;
reg [7:0] ulpi_reg_data_i_tmp;
reg [7:0] ulpi_reg_data_o_reg;
wire [7:0] ulpi_reg_data_o_tmp;
reg ulpi_reg_done_reg;
wire ulpi_reg_done_tmp;
reg [7:0] ulpi_rxcmd_reg;
wire [7:0] ulpi_rxcmd_tmp;
reg ulpi_reg_fail_reg;
wire ulpi_reg_fail_tmp;
reg ulpi_ready_reg;
wire ulpi_ready_tmp;

wire [7:0] ulpi_led;

ULPI ULPI_0 (
	.CLK_60M(CLK_60M),
	.NRST_A_USB(NRST_A_USB),
	.USB_DATA(USB_DATA),
	.USB_DIR(USB_DIR),
	.USB_FAULTN(USB_FAULT),
	.USB_NXT(USB_NXT),
	.USB_RESETN(USB_RESETN),
	.USB_STP(USB_STP),
	.USB_CS(USB_CS),
	.REG_RW(ulpi_reg_rw_tmp),
	.REG_EN(ulpi_reg_en_tmp),
	.REG_ADDR(ulpi_reg_addr_tmp),
	.REG_DATA_I(ulpi_reg_data_i_tmp),
	.REG_DATA_O(ulpi_reg_data_o_tmp),
	.REG_DONE(ulpi_reg_done_tmp),
	.REG_FAIL(ulpi_reg_fail_tmp),
	.RXCMD(ulpi_rxcmd_tmp),
	.READY(ulpi_ready_tmp),
	.LED(ulpi_led)
);

//-----------------------------------------------------------------------------
`define PARAM_SIZE 8
parameter RESET = `PARAM_SIZE'd1;
parameter W_FUN_CTRL = `PARAM_SIZE'd2;
parameter R_FUN_CTRL = `PARAM_SIZE'd3;
parameter WAIT = `PARAM_SIZE'd4;
parameter WRITE = `PARAM_SIZE'd5;
parameter READ  = `PARAM_SIZE'd6;
parameter IDLE = `PARAM_SIZE'd7;

`define REG_MAP_SIZE 6
parameter FUNC_CTRL_REG = `REG_MAP_SIZE'h04;

reg [`PARAM_SIZE - 1 : 0] state, state_tmp, last_state, last_state_tmp, next_state, next_state_tmp;
reg [7:0] reg_output, reg_output_tmp;

always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		ulpi_reg_data_o_reg <= 8'd0;
		ulpi_reg_done_reg <= 1'b0;
		ulpi_reg_fail_reg <= 1'b0;
		ulpi_rxcmd_reg <= 8'b0;
		ulpi_ready_reg <= 1'b0;

		state <= RESET;
		last_state <= RESET;

		reg_output <= 8'd0;
	end else begin
		ulpi_reg_data_o_reg <= ulpi_reg_data_o_tmp;
		ulpi_reg_done_reg <= ulpi_reg_done_tmp;
		ulpi_reg_fail_reg <= ulpi_reg_fail_tmp;
		ulpi_rxcmd_reg <= ulpi_rxcmd_tmp;
		ulpi_ready_reg <= ulpi_ready_tmp;

		state <= state_tmp;
		last_state <= last_state_tmp;

		reg_output <= reg_output_tmp;
	end
end

always @(NRST_A_USB, state, ulpi_reg_data_o_reg, ulpi_reg_done_reg, ulpi_reg_fail_reg, ulpi_rxcmd_reg, ulpi_ready_reg, last_state, next_state, reg_output) begin
	state_tmp = state;
	ulpi_reg_rw_tmp = 1'b0;
	ulpi_reg_en_tmp = 1'b0;
	last_state_tmp = last_state;	
	next_state_tmp = next_state;
	
	reg_output_tmp = reg_output;

	case (state)
	RESET: begin
		if (ulpi_ready_reg)
			state_tmp = W_FUN_CTRL;
	end
	W_FUN_CTRL: begin
		ulpi_reg_addr_tmp = FUNC_CTRL_REG;
		ulpi_reg_data_i_tmp = 8'b01000001;

		ulpi_reg_rw_tmp = 1'b1;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT;
		last_state_tmp = W_FUN_CTRL;
		next_state_tmp = R_FUN_CTRL;
	end
	R_FUN_CTRL: begin
		ulpi_reg_addr_tmp = FUNC_CTRL_REG;

		ulpi_reg_rw_tmp = 1'b0;
		ulpi_reg_en_tmp = 1'b1;
		state_tmp = WAIT;
		last_state_tmp = R_FUN_CTRL;
		next_state_tmp = IDLE;	
	end
	WAIT: begin
		if (ulpi_reg_done_reg) begin
			state_tmp = next_state;
			reg_output_tmp = ulpi_reg_data_o_reg;
		end else if (ulpi_reg_fail_reg) begin
			state_tmp = last_state;
		end
	end
	IDLE: begin
	
	end
	default: begin
		state_tmp = RESET;
	end
	endcase
end

//-----------------------------------------------------------------------------

reg [21:0] cnt;
reg testVal;
always @(posedge CLK_60M) begin
	cnt <= cnt + 1;
	if (!cnt) begin
		testVal <= !testVal;
	end
end

reg CLK_100M_tmp1, CLK_100M_tmp2;
always @(posedge CLK_100M, negedge NRST) begin
	if (!NRST) begin

		CLK_100M_tmp1 <= 1'b0;
		CLK_100M_tmp2 <= 1'b0;
		NRST_A_USB <= 1'b0;
		NRST_CLK_100M <= 1'b0;

	end else begin

		CLK_100M_tmp1 <= CLK_PLL_LOCKED & NRST;
		CLK_100M_tmp2 <= CLK_100M_tmp1;

		if (!CLK_100M_tmp2) begin
			NRST_CLK_100M <= 1'b0;
			NRST_A_USB <= 1'b0;
		end else begin
			NRST_CLK_100M <= 1'b1;
			NRST_A_USB <= 1'b1;
		end
	
	end
end

reg [25:0] cnt2;
reg testVal_synchr0, testVal_synchr1;
reg [1:0] testVal2;

reg [7:0] rxcmd_100, ulpi_led_100;
always @(posedge CLK_100M) begin
	rxcmd_100 <= ulpi_rxcmd_tmp;
	ulpi_led_100 <= ulpi_led;
end

assign LED = LED_internal;
always @(posedge CLK_100M) begin
	if (!NRST_CLK_100M) begin
		cnt2 <= 26'd0;
		testVal2 <= 2'd0;
		LED_internal <= 8'd0;
	end else begin

		cnt2 <= cnt2 + 1;
		if (!cnt2) begin
			testVal2 <= testVal2 + 1;
		end
		if (testVal2 == 0) begin
			testVal_synchr0 <= testVal;
			testVal_synchr1 <= testVal_synchr0;
			LED_internal <= { 6'b111111, testVal2, testVal_synchr1};
		end else if (testVal2 == 1) begin
			LED_internal <= ~rxcmd_100;
		end else if (testVal2 == 2) begin
			LED_internal <= ~ulpi_led_100;
		end else begin
			LED_internal <= ~reg_output;
		end
	
	end
end


endmodule
