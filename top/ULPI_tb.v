module ULPI_tb(output clk);

reg CLK, NRST, USB_DIR, USB_NXT, REG_RW, REG_EN, USB_DATA_IN_START_END;
reg [7:0] REG_DATA_I, USB_DATA_IN, data, USB_DATA_TO_ULPI;
reg [5:0] REG_ADDR;

wire USB_RESETN, USB_STP, USB_CS, REG_DONE, REG_FAIL, USB_DATA_IN_STRB;
wire USB_DATA_IN_FAIL, USB_DATA_OUT_STRB, USB_DATA_OUT_END, USB_DATA_OUT_FAIL;
wire [7:0] REG_DATA_O, USB_DATA_OUT, RXCMD, STATE, USB_DATA_IO;
wire [7:0] USB_DATA_FROM_ULPI;
wire READY;


assign clk = CLK;
assign USB_DATA_IO = USB_DIR ? USB_DATA_TO_ULPI : 8'hzz;
assign USB_DATA_FROM_ULPI = USB_DATA_IO;

ULPI DUT (
	.CLK_60M(CLK),
	.NRST_A_USB(NRST),
	.USB_DATA(USB_DATA_IO),
	.USB_DIR(USB_DIR),
	.USB_RESETN(USB_RESETN),
	.USB_NXT(USB_NXT),
	.USB_STP(USB_STP),
	.USB_CS(USB_CS),
	.REG_RW(REG_RW),
	.REG_EN(REG_EN),
	.REG_ADDR(REG_ADDR),
	.REG_DATA_I(REG_DATA_I),
	.REG_DATA_O(REG_DATA_O),
	.REG_DONE(REG_DONE),
	.REG_FAIL(REG_FAIL),
	.RXCMD(RXCMD),
	.READY(READY),
	.USB_DATA_IN(USB_DATA_IN),
	.USB_DATA_IN_STRB(USB_DATA_IN_STRB),
	.USB_DATA_IN_START_END(USB_DATA_IN_START_END),
	.USB_DATA_IN_FAIL(USB_DATA_IN_FAIL),
	.USB_DATA_OUT(USB_DATA_OUT),
	.USB_DATA_OUT_STRB(USB_DATA_OUT_STRB),
	.USB_DATA_OUT_END(USB_DATA_OUT_END),
	.USB_DATA_OUT_FAIL(USB_DATA_OUT_FAIL),
	.STATE(STATE)
); 

always begin //time = 20 something
	CLK <= 1'b0;
	repeat(2) begin
		CLK <= 1'b0;
		#10;	
		CLK <= 1'b1;
		#10;
	end	
end

always begin
	NRST <= 1'b0;
	#20;
	NRST <= 1'b1;
	repeat(250) begin
		#10000000;
	end
end

always begin
	// init our regs;
	data <= 0; 
	USB_DIR <= 0;
	USB_NXT <= 0;
	REG_RW <= 0;
	REG_EN <= 0;
	USB_DATA_IN_START_END <= 0;
	REG_DATA_I <= 0;
	USB_DATA_IN <= 0;
	REG_ADDR <= 0;
	USB_DATA_TO_ULPI <= 0;
	
	#11;
	if (USB_RESETN != 0) $finish;
	if (USB_STP != 1) $finish;	//USB_STP on reset should be 1
	#10; //CLK goes to 0
	if (CLK != 0) $finish;
	#10;//CLK went to 1

	#20; //now we are in IDLE

	if (READY != 1) $finish;

	//test rxcmd update
	repeat(10) begin
		data <= data + 1;
		#20;
		USB_DIR <= 1;
 		USB_DATA_TO_ULPI <= data;
		#20;
		// here we are in turnaround
		#20;
		// here should read and set RXCMD
		if (RXCMD != data) $finish;
		USB_DIR <= 0;
		#20;
		// turn around;
		#20;
		// idle;
	end

	data <= 6; //ommit fun_ctrl write as it has some twirks.
	#20;

	//test reg write
	//TODO FUN_CTRL_REG with RESET
	repeat(10) begin
		data <= data + 1;
		#20;
		REG_RW <= 1;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		REG_DATA_I <= data;
		#20;
		// input regs updated
		REG_RW <= 0;
		REG_EN <= 0;
		REG_ADDR <= 0;
		REG_DATA_I <= 0;
		#20;
		// we are in REG_WRITE;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 1;
		#20;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		#20;
		if (USB_DATA_FROM_ULPI != data) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 0;
		#20;
		if (USB_STP != 1) $finish;
		if (REG_DONE != 1) $finish;
		if (REG_FAIL == 1) $finish;
		#20;
		// we are in idle
	end	
	
	data <= 6;
	#20;

	//test reg write with fail
	//there are 4 moments, when fail may occure. Therefore this section is so long.
	repeat(10) begin
		data <= data + 1;
		#20;
		REG_RW <= 1;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		REG_DATA_I <= data;
		#20;
		REG_RW <= 0;
		REG_EN <= 0;
		REG_ADDR <= 0;
		REG_DATA_I <= 0;
		#20;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_DIR <= 1; //going into fail
		#20;
		if (REG_FAIL != 1) $finish;
		USB_DIR <= 0;
		#20;

		//we are in idle
		REG_RW <= 1;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		REG_DATA_I <= data;
		#20;
		REG_RW <= 0;
		REG_EN <= 0;
		REG_ADDR <= 0;
		REG_DATA_I <= 0;
		#20;
		// we are in REG_WRITE;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 1;
		#20;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_DIR <= 1;
		USB_NXT <= 0; //TODO here something, how USB_NXT behaves when USB_DIR == 1?
		#20;
		if (REG_FAIL != 1) $finish;
		USB_DIR <= 0;
		#20;

		//we are in idle
		REG_RW <= 1;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		REG_DATA_I <= data;
		#20;
		REG_RW <= 0;
		REG_EN <= 0;
		REG_ADDR <= 0;
		REG_DATA_I <= 0;
		#20;
		// we are in REG_WRITE;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 1;
		#20;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		#20;
		if (USB_DATA_FROM_ULPI != data) $finish;
		if (REG_FAIL == 1) $finish;
		USB_DIR <= 1;
		USB_NXT <= 0;
		#20;
		if (REG_FAIL != 1) $finish;
		if (USB_STP == 1) $finish;
		USB_DIR <= 0;
		#20;

		//we are in idle
		REG_RW <= 1;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		REG_DATA_I <= data;
		#20;
		REG_RW <= 0;
		REG_EN <= 0;
		REG_ADDR <= 0;
		REG_DATA_I <= 0;
		#20;
		// we are in REG_WRITE;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 1;
		#20;
		if (USB_DATA_FROM_ULPI != {2'b10, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		#20;
		if (USB_DATA_FROM_ULPI != data) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 0;
		#20;
		USB_DIR <= 1;
		if (REG_FAIL == 1) $finish;
//		if (REG_DONE == 1) $finish; //TODO...
		if (USB_STP != 1) $finish; 
		#20;
		if (REG_FAIL != 1) $finish;
		USB_DIR <= 0;
		#20;
	end

	//reg read with no fail
	repeat(10) begin
		data <= data + 1;
		#20;

		REG_RW <= 0;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		#20;
		
		REG_EN <= 0;
		REG_ADDR <= 0;
		#20;

		// we are in REG_READ;
		if (USB_DATA_FROM_ULPI != {2'b11, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		#20;	
	
		if (USB_DATA_FROM_ULPI != {2'b11, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_NXT <= 1;
		#20;
		USB_DIR <= 1;
		USB_NXT <= 0;
		USB_DATA_TO_ULPI <= data;
		if (REG_FAIL == 1) $finish;
		#20;
		USB_DIR <= 1;
		if (REG_FAIL == 1) $finish;
		#20;
		USB_DIR <= 0;
		if (REG_FAIL == 1) $finish;
		if (REG_DATA_O != data) $finish;
		#20;
	end
	
	// reg read fail check
	repeat(10) begin
		data <= data + 1;
		#20;

		REG_RW <= 0;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		#20;

		REG_EN <= 0;
		REG_ADDR <= 0;
		#20;
	
		if (USB_DATA_FROM_ULPI != {2'b11, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_DIR <= 1;
		#20;

		if (REG_FAIL != 1) $finish;
		USB_DIR <= 0;
		#20;

		REG_RW <= 0;
		REG_EN <= 1;
		REG_ADDR <= data[5:0];
		#20;

		REG_EN <= 0;
		REG_ADDR <= 0;
		#20;
	
		if (USB_DATA_FROM_ULPI != {2'b11, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;		
		#20;

		if (USB_DATA_FROM_ULPI != {2'b11, data[5:0]}) $finish;
		if (REG_FAIL == 1) $finish;
		USB_DIR <= 1;
		#20;

		if (REG_FAIL != 1) $finish;
		USB_DIR <= 0;
		#20;	
	end

	// USB write
	repeat(10) begin
		data <= data + 1;
		#20;

		USB_DATA_IN <= data;
		USB_DATA_IN_START_END <= 1;
		#20;

		USB_DATA_IN_START_END <= 0;
		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB != 1) $finish;
		#20;

		if (USB_DATA_FROM_ULPI != {2'b01, data[5:0]}) $finish;
		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB == 1) $finish;
		USB_NXT <= 0;	
		#20;

		if (USB_DATA_FROM_ULPI != {2'b01, data[5:0]}) $finish;
		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB == 1) $finish;
		USB_NXT <= 1;	
		#20;

		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB == 1) $finish;
		if (USB_DATA_FROM_ULPI != {2'b01, data[5:0]}) $finish;
		data <= data + 1;
		USB_DATA_IN <= data + 1;
		USB_NXT <= 1;
		#20;	

		repeat(5) begin	
			if (USB_DATA_IN_FAIL == 1) $finish;
			if (USB_DATA_IN_STRB != 1) $finish;
			if (USB_DATA_FROM_ULPI != data) $finish;
			USB_NXT <= 1;
			USB_DATA_IN <= data + 1;
			data <= data + 1;			
			#20;

			if (USB_DATA_IN_FAIL == 1) $finish;
			if (USB_DATA_IN_STRB != 1) $finish;
			if (USB_DATA_FROM_ULPI != data) $finish;
			USB_NXT <= 0;
			USB_DATA_IN <= data + 1;
			#20;

			if (USB_DATA_IN_FAIL == 1) $finish;
			if (USB_DATA_IN_STRB == 1) $finish;
			if (USB_DATA_FROM_ULPI != data) $finish;
			data <= data + 1;
			USB_NXT <= 1;
			#20;
		end

		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB != 1) $finish;
		if (USB_DATA_FROM_ULPI != data) $finish;
		USB_NXT <= 0;
		USB_DATA_IN <= data + 1;
		#20;
	
		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB == 1) $finish;
		if (USB_DATA_FROM_ULPI != data) $finish;
		USB_NXT <= 1;
		USB_DATA_IN_START_END <= 1;
		#20;		

		if (USB_DATA_IN_FAIL == 1) $finish;
		if (USB_DATA_IN_STRB == 1) $finish;
		if (USB_STP != 1) $finish;
		if (USB_DATA_FROM_ULPI == data) $finish; //TODO what should be here?
		USB_DATA_IN_START_END <= 0;
		USB_NXT <= 0;
		#20;		
	end
	//TODO USB write with fail	
	data <= 0;
	#20;

	repeat(10) begin
		data <= data + 1;
		#20;
	
		USB_DIR <= 1;
		USB_DATA_TO_ULPI <= data;
		#20;
	
		#20;	
	
		if (RXCMD != data) $finish;
		if (USB_DATA_OUT_STRB != 0) $finish;
		if (USB_DATA_OUT_END != 0) $finish;
		if (USB_DATA_OUT_FAIL != 0) $finish;
		data <= data + 1;
		USB_DATA_TO_ULPI <= data + 1;
		USB_NXT <= 1;
		#20;

		repeat(5) begin
			if (USB_DATA_OUT != data) $finish;
			if (USB_DATA_OUT_STRB != 1) $finish;
			if (USB_DATA_OUT_END != 0) $finish;
			if (USB_DATA_OUT_FAIL != 0) $finish;
			data <= data + 1;
			USB_DATA_TO_ULPI <= data + 1;
			#20;
		end
			
		USB_DIR <= 0;
		USB_NXT <= 0;
		#20;

		if (USB_DATA_OUT_STRB != 0) $finish;
		if (USB_DATA_OUT_END != 1) $finish;
		if (USB_DATA_OUT_FAIL != 0) $finish;
		data <= 0;
		#20;	
	end
		
	// end of simulation
	#300;	
	$finish;
end

endmodule
