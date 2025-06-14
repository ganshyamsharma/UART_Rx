module uart_rx #(parameter CLK_PER_BIT = 10417)		//i_clk divided by baud rate
(
	input i_clk, 
	input i_serial_data,
	output o_dv,
	output reg [7:0] o_rx_byte
);
	//
	//
	localparam s_idle = 0;
	localparam s_rx_start = 1;
	localparam s_rx_data = 2;
	localparam s_stop = 3;
	localparam s_final = 4;
	reg [2:0] r_state = 0, r_next_state = 0;
	//
	//
	reg [$clog2(CLK_PER_BIT)-1 : 0] r_clk_counter = 0;
	reg [3:0] r_bit_counter = 0;
	always @(*) begin
		case(r_state)
			s_idle: 
				begin
					r_next_state = i_serial_data ? s_idle : s_rx_start;
				end
			s_rx_start: 
				begin
					r_next_state = (r_clk_counter == CLK_PER_BIT) ? s_rx_data : s_rx_start;
				end
			s_rx_data:
				begin
					r_next_state = (r_bit_counter == 8) ? s_stop : s_rx_data;
				end
			s_stop:
				begin
					r_next_state = (r_clk_counter == CLK_PER_BIT) ? s_final : s_stop;					
				end
			s_final:
				begin
					r_next_state = s_idle;
				end
			default: r_next_state = s_idle;
		endcase
	end
	//
	//
	reg [7:0] r_rx_byte = 0;
	reg r_dv;
	reg r_stop_state_correct = 0;      // for correcting the state transition from data transmission to stop bit at mid of last data bit
	always @(posedge i_clk) begin
		r_state <= r_next_state;
		case(r_state)
		    s_idle:
		        begin
		            r_dv <= 0;
		        end
			s_rx_start: 
				begin
					if(r_clk_counter == CLK_PER_BIT)
						r_clk_counter <= 0;
					else
						r_clk_counter <= r_clk_counter + 1'b1;
				end
			s_rx_data:
				begin
					if(r_bit_counter < 8)
						begin
							if((r_clk_counter == (CLK_PER_BIT/2)) & (r_bit_counter == 0))
								begin
									r_rx_byte[r_bit_counter] <= i_serial_data;
									r_clk_counter <= 0;
									r_bit_counter <= r_bit_counter + 1;
								end
							else if((r_clk_counter == CLK_PER_BIT) & (r_bit_counter < 7))
								begin
									r_rx_byte[r_bit_counter] <= i_serial_data;
									r_clk_counter <= 0;
									r_bit_counter <= r_bit_counter + 1;
								end
							else if((r_clk_counter == (CLK_PER_BIT)) & (r_bit_counter == 7))
							     begin
							         r_clk_counter <= 0;
							         r_rx_byte[r_bit_counter] <= i_serial_data;
							         r_stop_state_correct <= 1;
							     end
							else if((r_stop_state_correct == 1) & (r_bit_counter == 7) & (r_clk_counter == CLK_PER_BIT/2))
							     begin
							         r_stop_state_correct <= 0;
							         r_bit_counter <= r_bit_counter + 1;
							         r_clk_counter <= 0;
							     end
							else
								begin
									r_clk_counter <= r_clk_counter + 1;
								end
						end
					else if(r_bit_counter == 8)
						begin
							r_bit_counter <= 0;
						end
				end
			s_stop:
				begin
                    if(r_clk_counter == (CLK_PER_BIT)) 
					   begin
					       r_clk_counter <= 0;		
					   end
					else
					   begin
						   r_clk_counter <= r_clk_counter + 1;
					   end
				end				
			s_final:
				begin
					r_dv <= 1'b1;
				end
		endcase
	end
	//
	//
	assign o_dv = r_dv;
	always @(posedge r_dv) begin
	   o_rx_byte <= r_rx_byte;
	   r_rx_byte <= 0;
	end
endmodule