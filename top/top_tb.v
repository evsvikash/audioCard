`include "../usb_core/rtl/verilog/usbf_defines.v"

module top_tb(
	output clk
);

reg clk60M, clk100M, nrst;

wire led, usb_clkout, usb_clkout_nopll, usb_cs, usb_dir, usb_faultn, usb_nxt;
wire usb_stp, usb_resetn;
wire [7:0] usb_data;

assign clk = clk100M;

top DUT (
	.CLK_50M(clk100M),
	.NRST(nrst),
	.USB_CLKIN(clk60M),
	.USB_CLKOUT(usb_clkout),
	.USB_CLKOUT_NOPLL(usb_clkout_nopll), 	
	.USB_CS(usb_cs),			
	.USB_DATA(usb_data),
	.USB_DIR(usb_dir),
	.USB_FAULTN(usb_faultn),
	.USB_NXT(usb_nxt),
	.USB_RESETN(usb_resetn),
	.USB_STP(usb_stp),
	.LED(led)
);

always begin
	clk60M = 1'b1;
	repeat(250) #20 clk60M = ~clk60M;
end

always begin
	clk100M = 1'b1;
	repeat(250) #10 clk100M = ~clk100M;
end

always begin
	nrst = 1'b0;
	repeat(5) #30 nrst = 1'b0;
	repeat(250) #1000 nrst = 1'b1;	
end

endmodule	
