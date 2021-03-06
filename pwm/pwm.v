`define PWM_BITS					10

module pwm (
	input  wire [7:0] b_addr_i ,
	input  wire [7:0] b_data_i ,
	output wire [7:0] b_data_o ,
	input  wire       b_write_i,
	input  wire       clk_i    ,
	input  wire       nrst_i   ,
	output wire       pwm_o
);

	reg [`PWM_BITS - 1:0] duty_cycle;
	reg [`PWM_BITS - 1:0] counter   ;

	reg  [ 7:0] ctl0          ;
	wire [12:0] counter_next  ;
	reg  [ 7:0] lfsr          ;
	wire        lfsr_feedback ;
	wire [ 7:0] lfsr_shifted  ;
	reg  [ 2:0] lfsr_shift    ;
	wire        cycle_complete;
	wire        ctl0_enable   ;
	wire [ 1:0] ctl0_ss       ;
	wire [12:0] cycle_value   ;

	// register i/o
	always @(posedge clk_i or negedge nrst_i) begin
		if(~nrst_i) begin
			ctl0 <= 0;
			duty_cycle <= 0;
			lfsr_shift <= 0;
		end else begin
			if (b_write_i) begin
				case (b_addr_i)
					'h00: begin
						ctl0 <= b_data_i;
						lfsr_shift <= 
							b_data_i[1:0] == 'b11 ? 3'h1 :
							b_data_i[1:0] == 'b10 ? 3'h3 :
							b_data_i[1:0] == 'b01 ? 3'h5 : 3'b0;
					end
					'h01: begin
						duty_cycle[`PWM_BITS - 1:8] <= b_data_i[`PWM_BITS - 8 - 1:0];
					end
					'h02: begin
						duty_cycle[7:0] <= b_data_i;
					end
				endcase
			end
		end
	end

	// lfsr
	always @(posedge clk_i or negedge nrst_i) begin
		if(~nrst_i) begin
			lfsr <= 8'hFF;
		end else begin
			if ((ctl0_ss != 0) & cycle_complete) begin 
				lfsr[0] <= lfsr_feedback;
				lfsr[1] <= lfsr[0];
				lfsr[2] <= lfsr[1] ^ lfsr_feedback;
				lfsr[3] <= lfsr[2] ^ lfsr_feedback;
				lfsr[4] <= lfsr[3] ^ lfsr_feedback;
				lfsr[5] <= lfsr[4];
				lfsr[6] <= lfsr[5];
				lfsr[7] <= lfsr[6];
			end
		end
	end

	// pwm output
	always @(posedge clk_i or negedge nrst_i) begin
		if(~nrst_i) begin
			counter <= 0;
		end else begin
			if (ctl0_enable) begin
				counter <= counter_next[`PWM_BITS - 1:0];
			end
		end
	end

	assign lfsr_feedback  = lfsr[7];
	assign cycle_complete = counter == ('b1 << `PWM_BITS) - 1;

	assign b_data_o =
		(b_addr_i == 'h00) ? ctl0 :
		(b_addr_i == 'h01) ? { 6'b0, duty_cycle[`PWM_BITS - 1:8] } :
		(b_addr_i == 'h02) ? duty_cycle[7:0] : 8'h00;

	assign lfsr_shifted = lfsr >> lfsr_shift;
	assign counter_next = counter + 1;
	
	assign cycle_value[12:0] = duty_cycle + lfsr_shifted;
	assign pwm_o = ctl0_enable && (counter < cycle_value);

	assign ctl0_enable  = ctl0[7];
	assign ctl0_ss[1:0] = ctl0[1:0];

endmodule