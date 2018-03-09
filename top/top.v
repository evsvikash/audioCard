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

wire clk_10MHz;

wire [23:0] token_0;
wire token_0_strb;
wire [7:0] data_o_0;
wire data_o_strb_0, data_o_end_0, data_o_fail_0, data_i_start_stop_0;
wire data_i_strb_0, data_i_fail_0;
wire [7:0] data_i_0, pid;

usb_handshake_multiplexer (
	.NRST(NRST),
	.USB_CLKIN(USB_CLKIN),
	.USB_CS(USB_CS),
	.USB_DATA(USB_DATA),
	.USB_DIR(USB_DIR),
	.USB_NXT(USB_NXT),
	.USB_RESETN(USB_RESETN),
	.USB_STP(USB_STP),
	.LED(LED),
	.clk_10MHz_o(clk_10MHz),

	.token_0(token_0),
	.token_0_strb(token_0_strb),
	.data_o_0(data_o_0),
	.data_o_strb_0(data_o_strb_0),
	.data_o_end_0(data_o_end_0),
	.data_o_fail_0(data_o_fail_0),
	.pid_o(pid),
	.data_i_0(data_i_0),
	.data_i_start_stop_0(data_i_start_stop_0),
	.data_i_strb_0(data_i_strb_0),
	.data_i_fail_0(data_i_fail_0)
);

endpoint_ctrl (
	.nrst(NRST),
	.clk(USB_CLKIN),
	.token_in(token_0),
	.token_in_strb(token_0_strb),
	.data_in(data_o_0),
	.data_in_strb(data_o_strb_0),
	.data_in_end(data_o_end_0),
	.data_in_fail(data_o_fail_0),
	.pid(pid),
	.data_o(data_i_0),
	.data_o_start_stop(data_i_start_stop_0),
	.data_o_strb(data_i_strb_0),
	.data_o_fail(data_i_fail_0)
);
endmodule
