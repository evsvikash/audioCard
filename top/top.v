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

reg ulpi_reg_rw_reg;
wire ulpi_reg_rw_tmp;
reg ulpi_reg_en_reg;
wire ulpi_reg_en_tmp;
reg [5:0] ulpi_reg_addr_reg;
wire[5:0]  ulpi_reg_addr_tmp;
reg [7:0] ulpi_reg_data_i_reg;
wire [7:0] ulpi_reg_data_i_tmp;
reg [7:0] ulpi_reg_data_o_reg;
wire [7:0] ulpi_reg_data_o_tmp;
reg ulpi_reg_done_reg;
wire ulpi_reg_done_tmp;
reg [7:0] ulpi_rxcmd_reg;
wire [7:0] ulpi_rxcmd_tmp;
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
	.REG_RW(ulpi_reg_rw_reg),
	.REG_EN(ulpi_reg_en_reg),
	.REG_ADDR(ulpi_reg_addr_reg),
	.REG_DATA_I(ulpi_reg_data_i_reg),
	.REG_DATA_O(ulpi_reg_data_o_tmp),
	.REG_DONE(ulpi_reg_done_tmp),
	.REG_FAIL(ulpi_reg_fail_tmp),
	.RXCMD(ulpi_rxcmd_tmp),
	.READY(ulpi_ready_tmp),
	.LED(ulpi_led)
);

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

//-----------------------------------------------------------------------------

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
			LED_internal <= 8'b01010101;
		end
	
	end
end


endmodule
