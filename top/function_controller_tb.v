`include "../usb_core/rtl/usbf_defines.v"

module function_controller_tb(
output clk_o
);

reg clk, rstn, wb_ack;
wire wb_we, wb_stb, wb_cyc, inta, intb;
wire [`USBF_UFC_HADR:0] wb_addr;
wire [31:0] wb_data_o, wb_data_i;

assign clk_o = clk;

function_controller DUT (
	.clk_i(clk),
	.nrst_i(rstn),
	.wb_addr_o(wb_addr),
	.wb_data_o(wb_data_o),
	.wb_data_i(wb_data_i),
	.wb_ack_i(wb_ack),
	.wb_we_o(wb_we),
	.wb_stb_o(wb_stb),
	.wb_cyc_o(wb_cyc),
	.inta_i(inta),
	.intb_i(intb)
);

initial begin
	clk = 1'b0;
	rstn = 1'b0;
	wb_ack = 1'b0;
	repeat(4) #10 clk = ~clk;
	rstn = 1'b1;
	repeat(6) #10 clk = ~clk;
	wb_ack = 1'b1;
	repeat(2) #10 clk = ~clk;
	wb_ack = 1'b0;
	repeat(6) #10 clk = ~clk;
	wb_ack = 1'b1;
	repeat(2) #10 clk = ~clk;
	wb_ack = 1'b0;
	repeat(20) #10 clk = ~clk;
end	 
endmodule