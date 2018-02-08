`include "../usb_core/rtl/usbf_defines.v"

module top_tb(
	output clk
);

reg clk60M, clk100M, nrst;

wire led, usb_clkout, usb_clkout_nopll, usb_cs, usb_faultn;
wire usb_stp, usb_resetn;

wire [7:0] usb_data_inout;
wire [7:0] usb_data_input;
reg [7:0] usb_data_output;

reg usb_dir, usb_nxt;
reg usb_last_dir;
wire write_possible;
assign usb_data_input = usb_data_inout;
assign write_possible = usb_last_dir && usb_dir;
assign usb_data_inout = (write_possible == 1'b1) ? usb_data_output : 8'hzz;

assign clk = clk100M;

top DUT (
	.NRST(nrst),
	.USB_CLKIN(clk60M),
	.USB_CS(usb_cs),			
	.USB_DATA(usb_data_inout),
	.USB_DIR(usb_dir),
	.USB_FAULTN(usb_faultn),
	.USB_NXT(usb_nxt),
	.USB_RESETN(usb_resetn),
	.USB_STP(usb_stp),
	.LED(led)
);

always begin
	clk60M = 1'b0;
	repeat(2) begin // #20
		clk60M = ~clk60M;
		#10;
	end
end

always begin
	nrst = 1'b0;
	#60;
	nrst = 1'b1;
	repeat(250) begin
		#10000000;
	end
end

endmodule	
