module endpoint_ctrl_tb (
	output clk
);

reg clk60M, nrst;

assign clk = clk60M;
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
	#10;
	nrst = 1'b1;
	repeat(250) begin
		#10000000;	
		#10000000;
	end	
end

reg [23:0] token_in;
reg token_in_strb, data_in_strb, data_in_end, data_in_fail, data_o_strb, data_o_fail;
reg [7:0] data_in, pid;
wire data_o;

endpoint_ctrl DUT (
	.nrst(nrst),
	.clk(clk60M),
	.token_in(token_in),
	.token_in_strb(token_in_strb),
	.data_in(data_in),
	.data_in_strb(data_in_strb),
	.data_in_end(data_in_end),
	.data_in_fail(data_in_fail),
	.pid(pid),
	.data_o(data_o),
	.data_o_start_stop(data_o_start_stop),
	.data_o_strb(data_o_strb),
	.data_o_fail(data_o_fail)
);

always begin
	#100;
	token_in <= 24'b111110000000000000101101;
	token_in_strb <= 1;
	#10;
	token_in_strb <= 0;
	#10;
end
