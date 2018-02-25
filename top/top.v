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
	.clk_10MHz_o(clk_10MHz)
);

endmodule
