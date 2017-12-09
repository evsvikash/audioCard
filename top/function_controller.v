`include "../usb_core/rtl/usbf_defines.v"

module function_controller (
	input clk_i,
	input nrst_i,
	output [`USBF_UFC_HADR:0] wb_addr_o,
	output [31:0] wb_data_o,
	input [31:0] wb_data_i,
	input wb_ack_i,
	output wb_we_o,
	output wb_stb_o,
	output wb_cyc_o,
	input inta_i,
	input intb_i,
	output [7:0] led_o
);

`define PARAM_SIZE 8
parameter IDLE = `PARAM_SIZE'd1;
parameter INIT_FA = `PARAM_SIZE'd2;
parameter INIT_INT_MSK = `PARAM_SIZE'd3;
parameter INIT_EP0_CSR = `PARAM_SIZE'd4;
parameter INIT_EP0_INT =  `PARAM_SIZE'd5;
parameter INIT_EP0_BUF0 = `PARAM_SIZE'd6;
parameter INIT_EP0_BUF1 = `PARAM_SIZE'd7;
parameter INIT_EP1_CSR = `PARAM_SIZE'd8;
parameter INIT_EP1_INT =  `PARAM_SIZE'd9;
parameter INIT_EP1_BUF0 = `PARAM_SIZE'd10;
parameter INIT_EP1_BUF1 = `PARAM_SIZE'd11;
parameter INTERRUPT = `PARAM_SIZE'd12;
parameter EP0_INT = `PARAM_SIZE'd13;
parameter EP1_INT = `PARAM_SIZE'd14;
parameter WB_RD = `PARAM_SIZE'd15;
parameter WB_WR = `PARAM_SIZE'd16;
parameter CHECK_INT = `PARAM_SIZE'd17;
parameter CHECK_EP0_INT = `PARAM_SIZE'd18;
parameter CHECK_EP1_INT = `PARAM_SIZE'd19;

reg [`PARAM_SIZE - 1:0] state, stateAfterWB;
reg [`PARAM_SIZE - 1:0] stateAfterWB_tmp;

reg wb_we, wb_stb, wb_cyc;
wire wb_ack, inta, intb;
reg [`USBF_UFC_HADR:0] wb_addr;
reg [31:0] wb_data;
reg [31:0] wb_read_result;
wire [31:0] wb_data_in;
reg [7:0] led, led_tmp;

assign inta = inta_i;
assign intb = intb_i;
assign wb_we_o = wb_we;
assign wb_stb_o = wb_stb;
assign wb_cyc_o = wb_cyc;
assign wb_addr_o = wb_addr;
assign wb_data_o = wb_data;
assign wb_data_in = wb_data_i;
assign wb_ack = wb_ack_i;
assign led_o = led;

reg regn;
reg regn_tmp;
reg [25:0] cnt, cnt_tmp;
reg [`USBF_UFC_HADR - 1 : 0] addr;
reg [`USBF_UFC_HADR - 1 : 0]  addr_tmp;
reg [31:0] data;
reg [31:0] data_tmp;

always @(state, regn, addr, data, stateAfterWB, wb_read_result, cnt)
begin

	wb_we = 1'b0;
	wb_stb = 1'b0;
	wb_cyc = 1'b0;
	wb_data = 32'd0;
	wb_addr = 0;

	led_tmp = led;	
	regn_tmp = 1'b0;
	addr_tmp = `USBF_UFC_HADR'h00;
	data_tmp = 32'd0;
	cnt_tmp = cnt + 1;
	stateAfterWB_tmp = IDLE;
	

	case (state)
	IDLE: begin
		led_tmp = ~wb_read_result[7:0];
		if (cnt == 0) begin
			regn_tmp = 1'b0;
			addr_tmp = `USBF_UFC_HADR'h48;
			stateAfterWB_tmp = IDLE;
		end
/*		if (wb_read_result[7:0])
			led_tmp = ~8'b1;
		if (wb_read_result[15:8])
			led_tmp = ~8'd2;
		if (wb_read_result[23:16])
			led_tmp = ~8'd3;
		if (wb_read_result[31:24])
			led_tmp = ~8'd4;
		else
			led_tmp = ~8'b11000011;*/
	end

	INIT_FA: begin
		// reset function address
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h04;
		stateAfterWB_tmp = INIT_EP0_CSR;
		data_tmp = 32'd0;

		led_tmp = ~INIT_FA;
	end

	INIT_EP0_CSR: begin
		/*
		 * UC_BSEL: RO			(2)
		 * UC_DPD:  RO			(2)
		 * EP_TYPE: Control Endpoint 	(2)
		 * TR_TYPE: Interrupt		(2)
		 * --------------------------------
		 * EP_DIS:  Normal operation	(2)
		 * EP_NO: 0			(4) <- endpoint number, you must assign to it.
		 * LRG_OK: 1			(1)
		 * SML_OK: 1			(1)
		 * --------------------------------
		 * DMAEN: 0			(1)
		 * RESERVED			(1)
		 * OTS_STOP: 0			(1)
		 * TR_FR: 1			(2)
		 * MAX_PL_SZ:			(11)
		 */
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h40;
		data_tmp = 32'h00030A00;
		stateAfterWB_tmp = INIT_EP0_BUF0;

		led_tmp = ~INIT_EP0_CSR;
	end

	INIT_EP0_BUF0: begin
		/*
		 * USED: 0			(1)
		 * BUF_SZ: 256			(14)
		 * BUF_PTR: 0			(17)
		 */
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h48;
		stateAfterWB_tmp = INIT_EP0_BUF1;
		data_tmp = 32'h10000000;

		led_tmp = ~INIT_EP0_BUF0;
	end

	INIT_EP0_BUF1: begin
		/*
		 * USED: 0			(1)
		 * BUF_SZ: 256			(14)
		 * BUF_PTR: 0x1000		(17)
		 */
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h4C;
		stateAfterWB_tmp = INIT_EP1_CSR;
		data_tmp = 32'h10001000;

		led_tmp = ~INIT_EP0_BUF1;
	end

	INIT_EP1_CSR: begin
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h50;
		stateAfterWB_tmp = INIT_EP1_BUF0;
		data_tmp = 32'b00000100000001010000101000000000;

		led_tmp = ~INIT_EP1_CSR;
	end

	INIT_EP1_BUF0: begin
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h58;
		stateAfterWB_tmp = INIT_EP1_BUF1;
		data_tmp = 32'h10002000;

		led_tmp = ~INIT_EP1_BUF0;
	end

	INIT_EP1_BUF1: begin
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h5c;
		stateAfterWB_tmp = INIT_EP0_INT;
		data_tmp = 32'h10003000;

		led_tmp = ~INIT_EP1_BUF1;
	end

	INIT_EP0_INT: begin
		// Allow every interrupt
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h44;
		stateAfterWB_tmp = INIT_EP1_INT;
		data_tmp = 32'h3f000000;

		led_tmp = ~INIT_EP0_INT;
	end

	INIT_EP1_INT: begin
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h54;
		stateAfterWB_tmp = INIT_INT_MSK;
		data_tmp = 32'h3f000000;

		led_tmp = ~INIT_EP1_INT;
	end

	INIT_INT_MSK: begin
		// Allow all interrupts on inta_i only (intb_i never interrupts).
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h08;
		stateAfterWB_tmp = IDLE;
		data_tmp = 32'h000001ff;	

		led_tmp = ~INIT_INT_MSK;
	end

	WB_WR: begin
		
		data_tmp = data;
		addr_tmp = addr;
		regn_tmp = regn;
		stateAfterWB_tmp = stateAfterWB;

		wb_we = 1'b1;
		wb_stb = 1'b1;
		wb_cyc = 1'b1;
		wb_data = data;
	
		if (regn) begin
			wb_addr = {1'b0, addr};
		end else begin
			wb_addr = {1'b1, addr};
		end	
		
	//	led_tmp = ~WB_WR;
	end
	WB_RD: begin

		addr_tmp = addr;
		regn_tmp = regn;
		stateAfterWB_tmp = stateAfterWB;

		wb_we = 1'b0;
		wb_stb = 1'b1;
		wb_cyc = 1'b1;
	
		if (regn) begin
			wb_addr = {1'b0, addr};
		end else begin
			wb_addr = {1'b1, addr};
		end

		led_tmp = ~WB_RD;
	end

	CHECK_INT: begin
		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h0C;
		stateAfterWB_tmp = INTERRUPT;

		led_tmp = ~CHECK_INT;
	end
	INTERRUPT: begin
		led_tmp = ~INTERRUPT;
	end
	EP0_INT: begin
		led_tmp = ~EP0_INT;
	end
	EP1_INT: begin
		led_tmp = ~EP1_INT;
	end
	CHECK_EP0_INT: begin

		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h44;
		stateAfterWB_tmp = EP0_INT;

		led_tmp = ~CHECK_EP0_INT;
		
	end
	CHECK_EP1_INT: begin

		regn_tmp = 1'b0;
		addr_tmp = `USBF_UFC_HADR'h54;
		stateAfterWB_tmp = EP1_INT;

		led_tmp = ~CHECK_EP1_INT;

	end
	default: begin
	end
	endcase
end

always @(posedge clk_i, negedge nrst_i)
begin
	if (!nrst_i) begin
		state <= INIT_FA;
		stateAfterWB <= INIT_FA;

		regn <= 1'b0;
		addr <= `USBF_UFC_HADR'h00;
		data <= 32'd0;
		wb_read_result <= 32'd0;
		cnt <= 26'd0;
		led <= ~8'd64;

	end else begin
		
		led <= led_tmp;

		regn <= regn_tmp;
		addr <= addr_tmp;
		data <= data_tmp;
		cnt <= cnt_tmp;	

		stateAfterWB <= stateAfterWB_tmp;

		case (state)
		IDLE: begin
			if (inta || intb) begin
				state <= CHECK_INT;
			end else if (cnt == 0) begin
				state <= WB_RD;
			end
		end
		INIT_FA: begin
			state <= WB_WR;
		end
		INIT_INT_MSK: begin
			state <= WB_WR;
		end
		INIT_EP0_CSR: begin
			state <= WB_WR;
		end
		INIT_EP0_INT: begin
			state <= WB_WR;
		end
		INIT_EP0_BUF0: begin
			state <= WB_WR;
		end
		INIT_EP0_BUF1: begin
			state <= WB_WR;
		end
		INIT_EP1_CSR: begin
			state <= WB_WR;
		end
		INIT_EP1_INT: begin
			state <= WB_WR;
		end
		INIT_EP1_BUF0: begin
			state <= WB_WR;
		end
		INIT_EP1_BUF1: begin
			state <= WB_WR;
		end	
		WB_WR: begin
			if (wb_ack) begin
				state <= stateAfterWB;
			end
		end
		WB_RD: begin
			if (wb_ack) begin
				state <= stateAfterWB;
				wb_read_result <= wb_data_in; 
			end
		end
		
		CHECK_INT: begin
			state <= WB_RD;
		end
		INTERRUPT: begin
			if (wb_read_result[28] || wb_read_result[25]) begin
				state <= INIT_FA;
			end else if (wb_read_result[1]) begin
				state <= CHECK_EP1_INT;
			end else if (wb_read_result[0]) begin
				state <= CHECK_EP0_INT;
			end else begin
				state <= IDLE;
			end
		end
		CHECK_EP0_INT: begin
			state <= WB_RD;
		end
		CHECK_EP1_INT: begin
			state <= WB_RD;
		end
		EP0_INT: begin
			state <= EP0_INT;
		end
		EP1_INT: begin
			state <= EP1_INT;
		end
		default: begin
			state <= INIT_FA;
		end
		endcase
	end
end	

endmodule	
