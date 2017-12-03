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

wire UTMI_TXVALID, UTMI_TXREADY, UTMI_RXVALID, UTMI_RXACTIVE, UTMI_RXERROR, UTMI_TERMSELECT;
wire UTMI_DPPPULLDOWN, UTMI_DMPULLDOWN, UTMI_XCVRSELECT;
wire USBF_WB_ACK, USBF_WB_WE, USBF_WB_STB, USBF_WB_CYC, USBF_INTA, USBF_INTB, USBF_SUSP;
wire USBF_SUSPENDM, USBF_DMA_REQ, USBF_VCONTROL_LOAD;
wire [3:0] USBF_VCONTROL_PAD;
wire [7:0] UTMI_DATA_O, UTMI_DATA_I, USB_DATA_I, USB_DATA_O;
wire [1:0] UTMI_OPMODE, UTMI_LINESTATE;
wire [31:0] USBF_WB_DATA_I, USBF_WB_DATA_O;
wire [`USBF_UFC_HADR:0] USBF_WB_ADDR;
wire [`USBF_SSRAM_HADR:0] SRAM_ADDR;
wire [31:0] SRAM_DATA, SRAM_DATA_I, SRAM_DATA_O;
wire SRAM_WE, SRAM_RE;

wire CLK_100M, CLK_PLL_LOCKED, CLK_50M, CLK_60M;
reg NRST_CLK_100M, NRST_FUN_CON;
reg USB_RESETN_s, USB_RESET_s;

wire USB_PHY_RESETN;

assign USB_DATA = (USB_DIR) ? 8'dz : USB_DATA_O;
assign USB_DATA_I = (USB_DIR) ? USB_DATA : 8'dz;

assign SRAM_DATA = (SRAM_WE) ? SRAM_DATA_O : 8'dz;
assign SRAM_DATA_I = (SRAM_WE) ? 8'dz : SRAM_DATA;

reg [7:0] LED_internal, LED_wb_check;
wire [7:0] LED_function_controller, LED_usbf_top, LED_ulpi_wrapper;
assign LED = LED_internal;

reg [22:0] cnt;
reg [25:0] cnt2;
reg testVal;
reg [2:0] testVal2;

always @(posedge CLK_60M) begin
	cnt <= cnt + 1;
	if (!cnt) begin
		testVal <= !testVal;
	end
end

always @(posedge CLK_100M) begin
	if (!NRST_CLK_100M) begin
		cnt2 <= 25'd1;
		testVal2 <= 2'd0;
	end else begin

		cnt2 <= cnt2 + 1;
		if (!cnt2) begin
			testVal2 <= testVal2 + 1;
			if (testVal2 == 3'd4)
				testVal2 <= 3'd0;
		end

		if (testVal2 == 3'd0)
			LED_internal <= LED_function_controller;
		else if (testVal2 == 3'd1)
			LED_internal <= LED_usbf_top;	
		else if (testVal2 == 3'd2)
			LED_internal <= LED_ulpi_wrapper;
		else if (testVal2 == 3'd3)
			LED_internal <= { 5'b11111, USBF_SUSPENDM, USBF_SUSP, testVal};
		else if (testVal2 == 3'd4)
			LED_internal <= LED_wb_check;
	
	end
end

assign USB_CS = 1'b1;
assign UTMI_DPPULLDOWN = 1'b0;
assign UTMI_DMPULLDOWN = 1'b0;
assign USB_RESETN = USB_RESETN_s;

assign LED_usbf_top = 8'd255;
assign LED_ulpi_wrapper = 8'd255;

reg CLK_100M_tmp1, CLK_100M_tmp2;
reg [24:0] cnt_rst;
always @(posedge CLK_100M) begin
	CLK_100M_tmp1 <= CLK_PLL_LOCKED & NRST;
	CLK_100M_tmp2 <= CLK_100M_tmp1;

	if (!CLK_100M_tmp2) begin
		cnt_rst <= 25'd1;
		NRST_CLK_100M <= 1'b0;
		NRST_FUN_CON <= 1'b0;
		USB_RESETN_s <= 1'b0;
		USB_RESET_s <= 1'b1;
	end else if (cnt_rst) begin
		cnt_rst <= cnt_rst + 1;

		if (cnt_rst < 500000) begin
			USB_RESETN_s <= 1'b0;
		end else begin
			USB_RESETN_s <= 1'b1;
		end

		if (cnt_rst < 500000 || USB_DIR == 1'b1) begin
			USB_RESET_s <= 1'b1;
			NRST_CLK_100M <= 1'b0;
			NRST_FUN_CON <= 1'b0;
		end else begin
			cnt_rst <= 25'd0;
			USB_RESET_s <= 1'b0;
			NRST_CLK_100M <= 1'b1;
			NRST_FUN_CON <= 1'b1;
		end
			
	end else begin
		NRST_CLK_100M <= 1'b1;
		NRST_FUN_CON <= 1'b1;
		USB_RESETN_s <= 1'b1;

		USB_RESET_s <= 1'b0;
	end
end
	
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

reg [7:0] WB_TEST_ADDR;
wire [7:0] WB_TEST_DATA_O;
wire WB_TEST_ACK;
reg WB_TEST_STB;
reg [1:0] WB_TEST_STATE;

always @(posedge CLK_60M, posedge USB_RESET_s) begin
	if (USB_RESET_s) begin
		WB_TEST_STB <= 1'b0;
		WB_TEST_ADDR <= 8'd0;
		LED_wb_check <= 8'd255;
		WB_TEST_STATE <= 2'd0;
	end else begin
		if (WB_TEST_STATE == 2'd0) begin
			if (WB_TEST_ACK == 1'b0) begin
				WB_TEST_STB <= 1'b1;
				WB_TEST_ADDR <= 8'd04;
				WB_TEST_STATE <= 2'd1;
			end
		end else if (WB_TEST_STATE == 2'd1) begin
			if (WB_TEST_ACK == 1'b1) begin
				WB_TEST_STB <= 1'b0;
				LED_wb_check <= WB_TEST_DATA_O;
				WB_TEST_STATE <= 2'd2;
			end
		end else begin
			WB_TEST_STATE <= WB_TEST_STATE;
			if (testVal)
				WB_TEST_STATE <= 2'd0;
		end
	end
end


ulpi_wrapper ulpi_wrapper_0 (
	// ULPI Interface (PHY)
	.ulpi_clk60_i(CLK_60M),
	.ulpi_rst_i(USB_RESET_s),
	.ulpi_data_i(USB_DATA_I),
	.ulpi_data_o(USB_DATA_O),
	.ulpi_dir_i(USB_DIR),
	.ulpi_nxt_i(USB_NXT),
	.ulpi_stp_o(USB_STP),
	
	// Register access (Wishbone pipelined access type)
	// NOTE: Tie inputs to 0 if unused
	.reg_addr_i(WB_TEST_ADDR),
	.reg_stb_i(WB_TEST_STB),
	.reg_we_i(1'b0),
	.reg_data_i(8'd0),
	.reg_data_o(WB_TEST_DATA_O),
	.reg_ack_o(WB_TEST_ACK),
	
	// UTMI Interface (SIE)
	.utmi_txvalid_i(UTMI_TXVALID),
	.utmi_txready_o(UTMI_TXREADY),
	.utmi_rxvalid_o(UTMI_RXVALID),
	.utmi_rxactive_o(UTMI_RXACTIVE),
	.utmi_rxerror_o(UTMI_RXERROR),
	.utmi_data_o(UTMI_DATA_O),
	.utmi_data_i(UTMI_DATA_I),
	.utmi_xcvrselect_i({1'b0, UTMI_XCVRSELECT}),
	.utmi_termselect_i(UTMI_TERMSELECT),
	.utmi_opmode_i(UTMI_OPMODE),
	.utmi_dppulldown_i(UTMI_DPPULLDOWN),
	.utmi_dmpulldown_i(UTMI_DMPULLDOWN),
	.utmi_linestate_o(UTMI_LINESTATE)
	//,.led(LED_ulpi_wrapper)	
);

usbf_top usbf_top_0 (
	.clk_i(CLK_100M),
	.rst_i(NRST_CLK_100M),
	.wb_addr_i(USBF_WB_ADDR),
	.wb_data_i(USBF_WB_DATA_I),
	.wb_data_o(USBF_WB_DATA_O),
	.wb_ack_o(USBF_WB_ACK),
	.wb_we_i(USBF_WB_WE),
	.wb_stb_i(USBF_WB_STB),
	.wb_cyc_i(USBF_WB_CYC),
	.inta_o(USBF_INTA),
	.intb_o(USBF_INTB),
	.dma_req_o(USBF_DMA_REQ),
	.dma_ack_i(16'b0),
	.susp_o(USBF_SUSP),
	.resume_req_i(1'b0),

	.phy_clk_pad_i(CLK_60M),
	.phy_rst_pad_o(USBF_PHY_RESETN),
	
	.DataOut_pad_o(UTMI_DATA_I),
	.TxValid_pad_o(UTMI_TXVALID),
	.TxReady_pad_i(UTMI_TXREADY),
	
	.DataIn_pad_i(UTMI_DATA_O),
	.RxValid_pad_i(UTMI_RXVALID),
	.RxActive_pad_i(UTMI_RXACTIVE),
	.RxError_pad_i(UTMI_RXERROR),
	
	.XcvSelect_pad_o(UTMI_XCVRSELECT),
	.TermSel_pad_o(UTMI_TERMSELECT),
	.SuspendM_pad_o(USBF_SUSPENDM),
	.LineState_pad_i(UTMI_LINESTATE),
	.OpMode_pad_o(UTMI_OPMODE),
	.usb_vbus_pad_i(1'b0),
	.VControl_Load_pad_o(USBF_VCONTROL_LOAD),
	.VControl_pad_o(USBF_VCONTROL_PAD),
	.VStatus_pad_i(8'b0),
	
	.sram_adr_o(SRAM_ADDR),
	.sram_data_i(SRAM_DATA_I),
	.sram_data_o(SRAM_DATA_O),
	.sram_re_o(SRAM_RE),
	.sram_we_o(SRAM_WE)

	//,.led(LED_usbf_top)
);

ram_sp_sr_sw #(.DATA_WIDTH(32), .ADDR_WIDTH(14)) ram_sp_sr_sw_0 (
	.clk(CLK_60M),
	.address(SRAM_ADDR),
	.data(SRAM_DATA),
	.cs(1'b1),
	.we(SRAM_WE),
	.oe(1'b1)
);

function_controller function_controller_0 (
	.clk_i(CLK_100M),
	.nrst_i(NRST_FUN_CON),
	.wb_addr_o(USBF_WB_ADDR),
	.wb_data_o(USBF_WB_DATA_I),
	.wb_data_i(USBF_WB_DATA_O),
	.wb_ack_i(USBF_WB_ACK),
	.wb_we_o(USBF_WB_WE),
	.wb_stb_o(USBF_WB_STB),
	.wb_cyc_o(USBF_WB_CYC),
	.inta_i(USBF_INTA),
	.intb_i(USBF_INTB),
	.led_o(LED_function_controller)
);

endmodule
