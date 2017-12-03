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
parameter INIT_EP1_CSR = `PARAM_SIZE'd13;
parameter INIT_EP1_INT =  `PARAM_SIZE'd14;
parameter INIT_EP1_BUF0 = `PARAM_SIZE'd15;
parameter INIT_EP1_BUF1 = `PARAM_SIZE'd16;
parameter END_WB_RD = `PARAM_SIZE'd8;
parameter END_WB_WR = `PARAM_SIZE'd9;
parameter INTERRUPT = `PARAM_SIZE'd10;
parameter EP0_INT = `PARAM_SIZE'd11;
parameter EP1_INT = `PARAM_SIZE'd12;

reg [`PARAM_SIZE - 1:0] state, stateAfterWB;

reg wb_we, wb_stb, wb_cyc;
wire wb_ack, inta, intb;
reg [`USBF_UFC_HADR:0] wb_addr;
reg [31:0] wb_data, wb_read_result;
wire [31:0] wb_data_in;
reg [7:0] led;

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

task WB_set_addr;
	input regn; //regn == 0 - write to register file; regn == 1 - to mem buffer
	input [`USBF_UFC_HADR - 1:0] addr;
begin
	if (regn) begin
		wb_addr <= {1'b0, addr};
	end else begin
		wb_addr <= {1'b1, addr};
	end
end
endtask

task WB_write;
	input regn;	
	input [`USBF_UFC_HADR - 1 : 0] addr;
	input [31:0] data;
	input [`PARAM_SIZE - 1 : 0] stateAfter;

begin
	wb_we = 1'b1;
	wb_stb = 1'b1;
	wb_cyc = 1'b1;
	wb_data = data;

	WB_set_addr(regn, addr);

	state <= END_WB_WR;
	stateAfterWB <= stateAfter;
end
endtask

task WB_read;
	input regn;
	input [`USBF_UFC_HADR - 1 : 0] addr;
	input [`PARAM_SIZE - 1 : 0] stateAfter;
begin
	wb_we = 1'b0;
	wb_stb = 1'b1;
	wb_cyc = 1'b1;

	WB_set_addr(regn, addr);

	state <= END_WB_RD;
	stateAfterWB <= stateAfter;
end
endtask
	
task WB_end_write;
begin
	if (wb_ack) begin
		wb_we <= 1'b0;
		wb_stb <= 1'b0;
		wb_cyc <= 1'b0;
		state <= stateAfterWB;
		stateAfterWB <= stateAfterWB;
	end else begin
		wb_we <= 1'b1;
		wb_stb <= 1'b1;
		wb_cyc <= 1'b1;
		state <= state;
		stateAfterWB <= stateAfterWB;
	end
end
endtask

task WB_end_read;
begin
	if (wb_ack) begin
		wb_read_result <= wb_data_in;
		wb_stb <= 1'b0;
		wb_cyc <= 1'b0;
		state <= stateAfterWB;
		stateAfterWB <= stateAfterWB;
	end else begin
		wb_stb <= 1'b1;
		wb_cyc <= 1'b1;
		state <= state;
		stateAfterWB <= stateAfterWB;
	end
end
endtask

task IDLE_state;
begin
	if (inta || intb) begin
		WB_read(1'b0, `USBF_UFC_HADR'h0C, INTERRUPT);
	end
end
endtask

task INTERRUPT_state;
begin
	// USB Reset or Attached
	if (wb_read_result[28:28] || wb_read_result[25:25]) begin
		state <= INIT_FA;
		stateAfterWB <= INIT_FA;
	end else if (wb_read_result[1:1]) begin
		WB_read(1'b0, `USBF_UFC_HADR'h54, EP1_INT);
	end else if (wb_read_result[0:0]) begin
		WB_read(1'b0, `USBF_UFC_HADR'h44, EP0_INT);
	end else begin
		state <= IDLE;
		stateAfterWB <= IDLE;
	end 
end
endtask

always @(posedge clk_i)
begin
	if (!nrst_i) begin
		wb_addr <= `USBF_UFC_HADR'd0;
		wb_data <= 32'd0;
		wb_we <= 1'b0;
		wb_stb <= 1'b0;
		wb_cyc <= 1'b0;
		state <= INIT_FA;
		stateAfterWB <= INIT_FA;
		wb_read_result <= 32'd0;
		led <= 8'd255;
	end else begin

		case (state)
		IDLE: begin
			IDLE_state();
//			led <= ~IDLE;
		end
		INIT_FA: begin
			// reset function address
			WB_write(1'b0, `USBF_UFC_HADR'h04, 32'd0, INIT_EP0_CSR);
//			led <= ~INIT_FA;
		end
		INIT_INT_MSK: begin
			// Allow all interrupts on inta_i only (intb_i never interrupts).
			WB_write(1'b0, `USBF_UFC_HADR'h08, 32'h000000ff, IDLE);
//			led <= ~INIT_INT_MSK;
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
				
			WB_write(1'b0, `USBF_UFC_HADR'h40, 32'h00030A00, INIT_EP0_INT);
//			led <= ~INIT_EP0_CSR;
		end
		INIT_EP0_INT: begin
			// Allow every interrupt
			WB_write(1'b0, `USBF_UFC_HADR'h44, 32'h3f3f0000, INIT_EP0_BUF0);
//			led <= ~INIT_EP0_INT;
		end
		INIT_EP0_BUF0: begin
			/*
			 * USED: 0			(1)
			 * BUF_SZ: 256			(14)
			 * BUF_PTR: 0			(17)
			 */
			WB_write(1'b0, `USBF_UFC_HADR'h48, 32'h02000000, INIT_EP0_BUF1);
//			led <= ~INIT_EP0_BUF0;
		end
		INIT_EP0_BUF1: begin
			/*
			 * USED: 0			(1)
			 * BUF_SZ: 256			(14)
			 * BUF_PTR: 0x1000		(17)
			 */
			WB_write(1'b0, `USBF_UFC_HADR'h4c, 32'h02001000, INIT_EP1_CSR);
//			led <= ~INIT_EP0_BUF1;
		end
		INIT_EP1_CSR: begin
			WB_write(1'b0, `USBF_UFC_HADR'h50, 32'b00000100000001010000101000000000, INIT_EP1_INT);
//			led <= ~INIT_EP1_CSR;
		end
		INIT_EP1_INT: begin
			WB_write(1'b0, `USBF_UFC_HADR'h54, 32'h3f3f0000, INIT_EP1_BUF0);
//			led <= ~INIT_EP1_INT;
		end
		INIT_EP1_BUF0: begin
			WB_write(1'b0, `USBF_UFC_HADR'h58, 32'h02002000, INIT_EP1_BUF1);
//			led <= ~INIT_EP1_BUF0;
		end
		INIT_EP1_BUF1: begin
			WB_write(1'b0, `USBF_UFC_HADR'h5c, 32'h02003000, INIT_INT_MSK);
//			led <= ~INIT_EP1_BUF1;
		end
		END_WB_WR: begin
			WB_end_write();
		//	led <= ~END_WB_WR; //CAUSES FPGA FREEZE
		end
		END_WB_RD: begin
			WB_end_read();
		//	led <= ~END_WB_RD;
		end
		INTERRUPT: begin
			INTERRUPT_state();
//			led <= ~INTERRUPT;
		end
		EP0_INT: begin
			state <= EP0_INT;
			led <= ~EP0_INT;
		end
		EP1_INT: begin
			state <= EP1_INT;
			led <= ~EP1_INT;
		end
		default: begin
			state <= IDLE;
			stateAfterWB <= IDLE;
			led <= 8'd255;

		end
		endcase
	end
		
end
endmodule	
