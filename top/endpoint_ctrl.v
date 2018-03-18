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
	input data_o_fail,

	output [7:0] led
);

reg [7:0] data_o_a;
reg data_o_start_stop_a;

`define PARAM_SIZE 8
parameter IDLE = `PARAM_SIZE'd0;
parameter DETECT_PID = `PARAM_SIZE'd1;
parameter DETECT_REQUEST_TYPE = `PARAM_SIZE'd2;
parameter DETECT_REQUEST = `PARAM_SIZE'd3;
parameter SET_ADDRESS = `PARAM_SIZE'd4;
parameter IGNORE_REST = `PARAM_SIZE'd5;
parameter SEND_ACK = `PARAM_SIZE'd6;
parameter SEND_NAK = `PARAM_SIZE'd7;
parameter SEND_END = `PARAM_SIZE'd8; 

reg [`PARAM_SIZE - 1 : 0] state, next_state;

reg [7:0] led_val;

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

parameter REQ_GET_STATUS = 8'd0;
parameter REQ_CLEAR_FEATURE = 8'd1;
parameter REQ_SET_FEATURE = 8'd2;
parameter REQ_SET_ADDRESS = 8'd5;
parameter REQ_GET_DESCRIPTOR = 8'd6;
parameter REQ_SET_DESCRIPTOR = 8'd7;
parameter REQ_GET_CONFIGURATION = 8'd8;
parameter REQ_SET_CONFIGURATION = 8'd9;
parameter REQ_GET_INTERFACE = 8'd10;
parameter REQ_SET_INTERFACE = 8'd11;
parameter REQ_SYNCH_FRAME = 8'd12;

parameter DESC_DEVICE = 8'd1;
parameter DESC_CONFIGURATION = 8'd2;
parameter DESC_STRING = 8'd3;
parameter DESC_INTERFACE = 8'd4;
parameter DESC_ENDPOINT = 8'd5;
parameter DESC_DEVICE_QUALIFIER = 8'd6;
parameter DESC_OTHER_SPEED_CONFIGURATION = 8'd7;
parameter DESC_INTERFACE_POWER = 8'd8;

assign data_o = data_o_a;
assign data_o_start_stop = data_o_start_stop_a;

always @(posedge clk, negedge nrst) begin
	if (!nrst) begin
		state <= IDLE;
		next_state <= IDLE;
		led_val <= 0;
	end else begin
	case (state)
	IDLE: begin
		if (token_in_strb) begin
			state <= DETECT_PID;
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
			next_state <= IDLE;
			if (data_in == REQ_SET_ADDRESS) begin
				led_val <= REQ_SET_ADDRESS;
				state <= SET_ADDRESS;
			end else if (data_in == REQ_CLEAR_FEATURE) begin
				led_val <= REQ_CLEAR_FEATURE;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_GET_CONFIGURATION) begin
				led_val <= REQ_GET_CONFIGURATION;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_GET_DESCRIPTOR) begin
				led_val <= REQ_GET_DESCRIPTOR;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_GET_STATUS) begin
				led_val <= 8'b00111100;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_SET_CONFIGURATION) begin
				led_val <= REQ_SET_CONFIGURATION;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_SET_DESCRIPTOR) begin
				led_val <= REQ_SET_DESCRIPTOR;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_SET_FEATURE) begin
				led_val <= REQ_SET_FEATURE;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else if (data_in == REQ_SET_INTERFACE) begin
				led_val <= REQ_SET_INTERFACE;
				state <= IGNORE_REST;
				next_state <= SEND_ACK;
			end else begin
				state <= IGNORE_REST;
				next_state <= SEND_NAK;
			end

		end else if (data_in_end || data_in_fail) begin
			state <= IDLE;
			led_val <= 8'b01010101;
		end
	end
	SET_ADDRESS: begin
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
	SEND_NAK: begin
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
		data_o_start_stop_a = 0;
	end
	DETECT_PID: begin
		data_o_a = 0;
		data_o_start_stop_a = 0;	
	end
	DETECT_REQUEST_TYPE: begin
		data_o_a = 0;
		data_o_start_stop_a = 0;	
	end
	DETECT_REQUEST: begin
		data_o_a = 0;
		data_o_start_stop_a = 0;	
	end
	SET_ADDRESS: begin
		data_o_a = 0;
		data_o_start_stop_a = 0;	
	end
	IGNORE_REST: begin
		data_o_a = 0;
		data_o_start_stop_a = 0;	
	end
	SEND_ACK: begin
		data_o_a = PID_ACK;
		data_o_start_stop_a = 1;
	end
	SEND_NAK: begin
		data_o_a = PID_NAK;
		data_o_start_stop_a = 1;
	end
	SEND_END: begin
		data_o_a = 0;
		if (data_o_strb)
			data_o_start_stop_a = 1;
		else
			data_o_start_stop_a = 0;
	end
	default: begin
		data_o_a = 0;
		data_o_start_stop_a = 0;
	end
	endcase
end

assign led = led_val;

endmodule


