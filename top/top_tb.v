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

assign usb_data_input = usb_data_inout;
assign usb_data_inout = (usb_dir == 1'b1) ? usb_data_output : 8'hzz;

assign clk = clk100M;

top DUT (
	.CLK(clk100M),
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

always begin
	clk100M = 1'b0;
	repeat(2) begin // #10
		clk100M = ~clk100M;
		#5;
	end
end

always begin
	usb_dir = 1'b1;
	usb_nxt = 1'b0;
	usb_data_output = 8'd0;
	#140;
	if (usb_resetn) begin
		#81;
		usb_dir = 1'b0; // go to POST_RESET
		#80;
		usb_dir = 1'b1; // send rxcmd 
		usb_data_output = 8'd64;
		#40;
		usb_dir = 1'b0; // turnaround, wait for a CTRL REG write
		#80;
		usb_nxt = 1'b1;	// we are writing something
		#40;
		usb_nxt = 1'b0;
		if (!usb_stp) begin
			repeat(250) begin
				#10000000;
			end	
		end
/*		#80;
		usb_nxt = 1'b1;
		#20;
		usb_nxt = 1'b0;
		usb_dir = 1'b1;
		#40;
		usb_dir = 1'b0;*/
		repeat(250) begin
			#10000000;
		end	
	end
end

endmodule	
