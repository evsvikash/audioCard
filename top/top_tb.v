`timescale 1 ps / 1 ps
module top_tb(
	output clk
);

reg clk60M, nrst;

wire usb_clkout, usb_clkout_nopll, usb_cs, usb_faultn;
wire usb_stp, usb_resetn;

wire [7:0] usb_data_inout, led;
wire [7:0] usb_data_input;
reg [7:0] usb_data_output;

reg usb_dir, usb_nxt;
wire write_possible;
assign usb_data_input = usb_data_inout;
assign write_possible = usb_dir;
assign usb_data_inout = (write_possible == 1'b1) ? usb_data_output : 8'hzz;

assign clk = clk60M;

top DUT (
	.NRST(nrst),
	.USB_CLKIN(clk60M),
	.USB_CS(usb_cs),			
	.USB_DATA(usb_data_inout),
	.USB_DIR(usb_dir),
	.USB_NXT(usb_nxt),
	.USB_RESETN(usb_resetn),
	.USB_STP(usb_stp),
	.LED(led)
);

always begin
	clk60M = 1'b0;
	repeat(2) begin // #10
		clk60M = ~clk60M;
		#5;
	end
end

always begin
	nrst <= 1'b0;
	#10;
	nrst = 1'b1;
	repeat(250) begin
		#10000000;	
		#10000000;
	end

		
end

always begin
	usb_dir <= 1;
	usb_nxt <= 0;
	usb_data_output <= 0;
	#10;
	if (usb_stp != 1) $finish;
	#61;
	#10;
	if (usb_stp == 1) $finish;
	usb_dir <= 0;
	#10;
	if (usb_stp == 1) $finish;
	#10;
	// we are in W_OTG_CTRL_REG, but ULPI is idling (or should)
	#10;
	#10;
	// now ULPI should be writting
	if (usb_data_input != 8'b10001010) $finish;
	usb_nxt <= 1;
	#10;
	if (usb_data_input != 8'b10001010) $finish;
	usb_nxt <= 1;
	#10;
	usb_nxt <= 0;
	if (usb_data_input != 0) $finish;
	#10;
	if (usb_stp != 1) $finish;
	//SET_ULPI_START;
	#3900000; //#65000 * 10; 
	#10;
	#10;
	#10;
	if (usb_data_input != 8'b10000100) $finish;
	usb_nxt <= 1;
	#10;
	if (usb_data_input != 8'b10000100) $finish;
	usb_nxt <= 1;	
	#10;
	if (usb_data_input != 8'b01100101) $finish;
	usb_nxt <= 0;
	#10;
	if (usb_stp != 1) $finish;
	#10;
	usb_dir <= 1;
	#160; // we are resetting
	usb_dir <= 0;
	#10;
	usb_dir <= 1;
	usb_data_output <= 8'b01010100;
 	#10;
	#10;
	usb_dir <= 0;
	#10;
	#10;
	#1500; //detecting SE0, 25 * 10 * 6
	//---------------------- FAILING HERE
	if (usb_data_input != 8'b10000100) $finish;
	usb_nxt <= 1;
	#10;
	if (usb_data_input != 8'b10000100) $finish;
	#10;
	usb_nxt <= 0;
	if (usb_data_input != 8'b01010100) $finish;
	#10;
	if (usb_stp != 1) $finish;
	#10;
	#10;
	#10;
	if (usb_data_input != 8'b01000000) $finish;
	usb_nxt <= 1;
	#10;
	if (usb_data_input != 8'b01000000) $finish;
	usb_nxt <= 1;
	#10;		
	// now we should receive chirp K for at least 2ms (constant 0)
	repeat(6 * 20000) begin
		if (usb_data_input != 0) $finish;
		usb_nxt <= 1;	
		#10;
	end
	usb_nxt <= 0;
	if (usb_data_input != 0) $finish;
	#10;
	#10;
	if (usb_stp != 1) $finish;

	repeat(4) begin
		// now we should send K-J-K-J-K-J sequence
		//send K
		usb_data_output <= 8'b01010110;
		usb_dir <= 1;
		#10;
		#10;
		usb_dir <= 0;
		// wait for 3ms (6 * 30 * 10 + 100)
		#1900;

		//send J
		usb_dir <= 1;
		usb_data_output <= 8'b01010101;
		#10;
		#10;
		usb_dir <= 0;
		#1900;
	end
	#10;
	if (usb_data_input != 8'b10000100) $finish;
	usb_nxt <= 1;
	#10;
	if (usb_data_input != 8'b01000000) $finish;
	usb_nxt <= 0;
	#10;
	if (usb_stp != 1) $finish;
		
	#300;
	$finish;
		
end

endmodule	
