module top (
	input	NRST,

	input	USB_CLKIN,     		//Phy OUTPUT 60Mhz Clock 
	output	USB_CS,			//USB PHY select (1 - phy selected)
	inout	[7:0] USB_DATA,
	input	USB_DIR,
	input	USB_NXT,
	output	USB_RESETN,		//Reset PHY
	output	USB_STP,

	inout [7:0] LED
);


//Clock wires
wire CLK_60M;

//NRST wire
wire NRST_A_USB;

/*BUFG BUFG_0 (
	.inclk(CLK),
	.outclk(CLK_50M)
);
BUFG BUFG_1 (
	.inclk(USB_CLKIN),
	.outclk(CLK_60M)
);*/

assign CLK_60M = USB_CLKIN;
assign NRST_A_USB = NRST;

/*clk_pll_100M clk_pll_100M_0 (
	.areset(1'b0),
	.inclk0(CLK_50M),
	.c0(CLK_100M),
	.locked(CLK_PLL_LOCKED)
);*/



wire [7:0] ulpi_reg_data_o_a;
reg [7:0] ulpi_reg_data_i_a;
reg [5:0] ulpi_reg_addr_a;
wire [7:0] ulpi_rxcmd_a;
wire ulpi_ready_a, ulpi_reg_done_a, ulpi_reg_fail_a;
reg ulpi_reg_rw_a, ulpi_reg_en_a;

ULPI ULPI_0 (
	.CLK_60M(CLK_60M),
	.NRST_A_USB(NRST_A_USB),
	.USB_DATA(USB_DATA),
	.USB_DIR(USB_DIR),
	.USB_NXT(USB_NXT),
	.USB_RESETN(USB_RESETN),
	.USB_STP(USB_STP),
	.USB_CS(USB_CS),
	.REG_RW(ulpi_reg_rw_a),
	.REG_EN(ulpi_reg_en_a),
	.REG_ADDR(ulpi_reg_addr_a),
	.REG_DATA_I(ulpi_reg_data_i_a),
	.REG_DATA_O(ulpi_reg_data_o_a),
	.REG_DONE(ulpi_reg_done_a),
	.REG_FAIL(ulpi_reg_fail_a),
	.RXCMD(ulpi_rxcmd_a),
	.READY(ulpi_ready_a)
);

//-----------------------------------------------------------------------------
`define PARAM_SIZE 8
parameter RESET = `PARAM_SIZE'd1;
parameter W_FUN_CTRL_REG = `PARAM_SIZE'd2;
parameter R_FUN_CTRL_REG = `PARAM_SIZE'd3;
parameter W_OTG_CTRL_REG = `PARAM_SIZE'd4;
parameter R_OTG_CTRL_REG = `PARAM_SIZE'd5;
parameter W_SCR_REG  = `PARAM_SIZE'd6;
parameter R_SCR_REG  = `PARAM_SIZE'd7;
parameter WAIT_RD = `PARAM_SIZE'd8;
parameter WAIT_WR = `PARAM_SIZE'd9;
parameter IDLE = `PARAM_SIZE'd10;

`define REG_MAP_SIZE 6
parameter FUN_CTRL_REG = `REG_MAP_SIZE'h04;
parameter OTG_CTRL_REG  = `REG_MAP_SIZE'h0A;
parameter SCRATCH_REG   = `REG_MAP_SIZE'h16;

reg [`PARAM_SIZE - 1 : 0] state, next_state, previous_state;
reg [7 : 0] ulpi_reg_data_o, ulpi_rxcmd_o;
reg [12 : 0] scratch_wr_rd;

always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin

		state <= RESET;
		next_state <= RESET;
		previous_state <= RESET;
		ulpi_reg_data_o <= 8'd0;
		ulpi_rxcmd_o <= 8'd0;
		scratch_wr_rd <= 0;

	end else begin

		ulpi_rxcmd_o <= ulpi_rxcmd_a;
	
		if (!ulpi_ready_a) begin

			state <= RESET;
			next_state <= RESET;
			previous_state <= RESET;

		end else begin
	
			case (state)
			RESET: begin
				state <= W_OTG_CTRL_REG;
			end
			IDLE: begin
				scratch_wr_rd <= scratch_wr_rd + 1;
				if (scratch_wr_rd == 1)
					state <= R_SCR_REG;
				else if (scratch_wr_rd == 2048)
					state <= R_FUN_CTRL_REG;
			end
			W_OTG_CTRL_REG: begin
				state <= WAIT_WR; 
				next_state <= W_FUN_CTRL_REG;
				previous_state <= state;
			end
			W_FUN_CTRL_REG: begin
				state <= WAIT_WR;
				next_state <= IDLE;
				previous_state <= state;
			end
			R_FUN_CTRL_REG: begin
				state <= WAIT_RD;
				next_state <= IDLE;
				previous_state <= state;
			end
			W_SCR_REG: begin
				state <= WAIT_WR;
				next_state <= IDLE;
				previous_state <= state;
			end
			R_SCR_REG: begin
				state <= WAIT_RD;
				next_state <= IDLE;
				previous_state <= state;
			end
			WAIT_WR: begin
				if (ulpi_reg_done_a) begin
					state <= next_state;
				end else if (ulpi_reg_fail_a) begin
					state <= previous_state;
				end
			end
			WAIT_RD: begin
				if (ulpi_reg_done_a) begin
					state <= next_state;
					ulpi_reg_data_o <= ulpi_reg_data_o_a;
				end else if (ulpi_reg_fail_a) begin
					state <= previous_state;
				end
			end
			default: begin
				state <= RESET;
			end
			endcase
		end
	end
end

reg [24:0] LED_cnt;
reg LED_switch;
reg [7:0] LED_output;

always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		LED_cnt <= 0;
		LED_switch <= 0;
	end else begin
		LED_cnt <= LED_cnt + 1;
		if (!LED_cnt)
			LED_switch <= LED_switch + 1;
	end
end

always @(LED_switch) begin
	if (LED_switch)
		LED_output <= ulpi_rxcmd_o;
	else
		LED_output <= ulpi_reg_data_o;
end

assign LED = ~LED_output;

reg [20:0] cnt;
reg[7:0] small_cnt;
always @(posedge CLK_60M, negedge NRST_A_USB) begin
	if (!NRST_A_USB) begin
		cnt <= 0;
		small_cnt <= 8'd0;
	end else begin
		cnt <= cnt + 1;
		if (!cnt) begin
			small_cnt <= small_cnt + 1;
		end
	end
end

always @(state, small_cnt) begin
	case (state)
	RESET: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;
	end
	IDLE: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;
	end
	W_FUN_CTRL_REG: begin
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = 8'b01100110;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;
	end
	R_FUN_CTRL_REG: begin
		ulpi_reg_addr_a = FUN_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;
	end
	W_OTG_CTRL_REG: begin
		ulpi_reg_addr_a = OTG_CTRL_REG;
		ulpi_reg_data_i_a = 0;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1; 
	end
	W_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = small_cnt;
		ulpi_reg_rw_a = 1'b1;
		ulpi_reg_en_a = 1'b1;
	end
	R_SCR_REG: begin
		ulpi_reg_addr_a = SCRATCH_REG;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b1;
	end
	WAIT_WR: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;
	end
	WAIT_RD: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;	
	end
	default: begin
		ulpi_reg_addr_a = 6'd0;
		ulpi_reg_data_i_a = 8'd0;
		ulpi_reg_rw_a = 1'b0;
		ulpi_reg_en_a = 1'b0;	
	end
	endcase
end

endmodule
