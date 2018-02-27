`timescale 1 ps / 1 ps
module usb_handshake_multiplexer_tb(
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

wire token_0_strb, clk_10MHz, data_o_strb_0, data_o_end_0, data_o_fail_0;

wire [7:0] data_o_0;
wire [23:0] token_0; 
wire [7:0] pid;

usb_handshake_multiplexer DUT (
	.NRST(nrst),
	.USB_CLKIN(clk60M),
	.USB_CS(usb_cs),			
	.USB_DATA(usb_data_inout),
	.USB_DIR(usb_dir),
	.USB_NXT(usb_nxt),
	.USB_RESETN(usb_resetn),
	.USB_STP(usb_stp),
	.LED(led),

	.clk_10MHz_o(clk_10MHz),
	.token_0(token_0),
	.token_0_strb(token_0_strb),
	.data_o_0(data_o_0),
	.data_o_strb_0(data_o_strb_0),
	.data_o_end_0(data_o_end_0),
	.data_o_fail_0(data_o_fail_0),
	.pid_o(pid)
);

always begin
	clk60M = 1'b0;
	repeat(2) begin // #10
		clk60M = ~clk60M;
		#5;
	end
end

reg [7:0] data;
always begin
	nrst <= 1'b0;
	data <= 0;
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
	if (usb_data_input != 8'b10000100) $finish;
	usb_nxt <= 1;
	#10;
	if (usb_data_input != 8'b01000000) $finish;
	usb_nxt <= 0;
	#10;
	if (usb_stp != 1) $finish;
	#10;

	usb_dir <= 1;
	#10;

	repeat(5) begin

		//send SETUP token
		usb_data_output <= 8'b00010000;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		usb_dir <= 1;
		
		#10;
		usb_nxt <= 1;
		usb_data_output <= 8'b00101101;
		usb_dir <= 1;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
		//EP == 4'b0000;
		//ADDR == 7'b1110110
		//CRC == TO BE DONE
		usb_data_output <= 8'b01100000;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
		usb_data_output <= 8'b00000111;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
		usb_dir <= 0;
		usb_nxt <= 0;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
		if (token_0_strb == 0) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		if (token_0 != 23'b000001110110000000101101) $finish;
		#10;
	
		//send DATA token
		usb_dir <= 1;
		#10;
		usb_dir <= 1;
		usb_data_output <= 8'b00010000;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
	
		usb_nxt <= 1;
		usb_data_output <= 8'b11000011;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
	
		#10;
		usb_nxt <= 1;
		usb_data_output <= data + 1;
		data <= data + 1;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
	
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 != 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		if (data_o_0 != data) $finish;
		if (pid != 8'b11000011) $finish;
		usb_nxt <= 1;
		usb_data_output <= data + 1;
		data <= data + 1;
	
		repeat(250) begin
			#10;	
			if (token_0_strb == 1) $finish;
			if (data_o_strb_0 != 1) $finish;
			if (data_o_end_0 == 1) $finish;
			if (data_o_fail_0 == 1) $finish;
			if (data_o_0 != data) $finish;
			usb_data_output <= data + 1;
			data <= data + 1;
		end
	
		usb_nxt <= 0;
		usb_dir <= 0;
		#10;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 != 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;


		//data_o_fail_0 test
		//send DATA token
		usb_dir <= 1;
		#10;
		usb_dir <= 1;
		usb_data_output <= 8'b00010000;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
	
		usb_nxt <= 1;
		usb_data_output <= 8'b11000011;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
	
		#10;
		usb_nxt <= 1;
		usb_data_output <= data + 1;
		data <= data + 1;
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		#10;
	
		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 != 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 == 1) $finish;
		if (data_o_0 != data) $finish;
		if (pid != 8'b11000011) $finish;
		usb_nxt <= 1;
		usb_data_output <= data + 1;
		data <= data + 1;
	
		repeat(10) begin
			#10;	
			if (token_0_strb == 1) $finish;
			if (data_o_strb_0 != 1) $finish;
			if (data_o_end_0 == 1) $finish;
			if (data_o_fail_0 == 1) $finish;
			if (data_o_0 != data) $finish;
			usb_data_output <= data + 1;
			data <= data + 1;
		end
	
		usb_nxt <= 0;
		usb_dir <= 1;
		usb_data_output <= 8'b00110000;
		#10;

		if (token_0_strb == 1) $finish;
		if (data_o_strb_0 == 1) $finish;
		if (data_o_end_0 == 1) $finish;
		if (data_o_fail_0 != 1) $finish;
		#10;
		
	end

	#300;
	
	$finish;
		
end

endmodule	
