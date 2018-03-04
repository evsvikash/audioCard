module endpoint_ctrl (
	input nrst,
	input clk,
	input [23:0] token_in,
	input token_in_strb,
	input [7:0] data_in,
	input data_in_strb,
	input data_in_end,
	input data_in_fail,
	input [7:0] pid,

	output [7:0] data_o,
	output data_o_start_stop,
	input data_o_strb,
	input data_o_fail
);

reg [7:0] data_o_a;
reg data_o_start_stop_a;

`define PARAM_SIZE 8
parameter IDLE = `PARAM_SIZE'd0;
parameter DETECT_PID = `PARAM_SIZE'd1;
parameter DETECT_REQUEST_TYPE = `PARAM_SIZE'd2;
parameter DETECT_REQUEST = `PARAM_SIZE'd3;
parameter GET_ADDRESS = `PARAM_SIZE'd4;
parameter IGNORE_REST = `PARAM_SIZE'd5;
parameter SEND_ACK = `PARAM_SIZE'd6;
parameter SEND_END = `PARAM_SIZE'd7; 

reg [`PARAM_SIZE - 1 : 0] state, next_state;
reg [7:0] cnt_to_ignore;
reg toggle_bit;

parameter PID_OUT = 8'b11100001;
parameter PID_IN  = 8'b01101001;
parameter PID_SOF = 8'b10100101;
parameter PID_SETUP = 8'b00101101;
parameter PID_DATA0 = 8'b11000011;
parameter PID_DATA1 = 8'b01001011;
parameter PID_DATA2 = 8'b10000111;
parameter PID_MDATA = 8'b00001111;
parameter PID_ACK = 8'b11010010;
parameter PID_NAK = 8'b01011010;
parameter PID_STALL = 8'b00011110;
parameter PID_NYET = 8'b10010110;
parameter PID_PING = 8'b10110100;

parameter SET_ADDRESS = 8'd5;

assign data_o = data_o_a;
assign data_o_start_stop = data_o_start_stop_a;

always @(posedge clk, negedge nrst) begin
	if (!nrst) begin
		state <= IDLE;
		next_state <= IDLE;
		toggle_bit <= 0;
		cnt_to_ignore <= 0;
	end else begin
	case (state)
	IDLE: begin
		if (token_in_strb) begin
			state <= DETECT_PARITY;
		end
	end
	DETECT_PID: begin

		if (data_in_strb) begin
			state <= DETECT_REQUEST_TYPE;
		end else if (data_in_end || data_in_fail) begin
			state <= IDLE;
		end		
	end
	DETECT_REQUEST_TYPE: begin
		if (data_in_strb)
			state <= DETECT_REQUEST;
		else if (data_in_end || data_in_fail)
			state <= IDLE;
	end
	DETECT_REQUEST: begin
		if (data_in_strb) begin
			if (data_in == SET_ADDRESS) begin
				state <= GET_ADDRESS;
			end else begin
				state <= IDLE;
			end
		end else if (data_in_end || data_in_fail) begin
			state <= IDLE;
		end
	end
	GET_ADDRESS: begin
		if (data_in_strb) begin
			next_state <= SEND_ACK;
			state <= IGNORE_REST;
		end else if (data_in_end || data_in_fail) begin
			state <= IDLE;
		end
	end
	IGNORE_REST: begin
		if (data_in_end) begin
			state <= next_state;
		end else if (data_in_fail) begin
			state <= IDLE;
		end
	end
	SEND_ACK: begin
		state <= SEND_END;
	end
	SEND_END: begin
		if (data_o_strb) begin
			state <= IDLE;
		end else begin
	
		end
	end
	default: begin
		state <= IDLE;
	end	
	endcase	
	end
end

always @(state, data_o_strb) begin
	case (state)
	IDLE: begin
		data_o_a = 0;
		data_o_start_stop = 0;
	end
	DETECT_PID: begin
		data_o_a = 0;
		data_o_start_stop = 0;	
	end
	DETECT_REQUEST_TYPE: begin
		data_o_a = 0;
		data_o_start_stop = 0;	
	end
	DETECT_REQUEST: begin
		data_o_a = 0;
		data_o_start_stop = 0;	
	end
	GET_ADDRESS: begin
		data_o_a = 0;
		data_o_start_stop = 0;	
	end
	IGNORE_REST: begin
		data_o_a = 0;
		data_o_start_stop = 0;	
	end
	SEND_ACK: begin
		data_o_a = PID_ACK;
		data_o_start_stop = 1;
	SEND_END: begin
		data_o_a = 0;
		if (data_o_strb)
			data_o_start_stop = 1;
		else
			data_o_start_stop = 0;
	end	
end

endmodule


