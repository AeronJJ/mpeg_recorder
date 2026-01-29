`default_nettype none
module msp2807_touch_spi 
   (
    input wire	       rst_n,
    input wire	       sys_clk_1MHz,
    input wire	       en,

    input wire [7:0]   data_in,
    input wire	       sdo_in,
    /* verilator lint_off UNUSEDSIGNAL */
    input wire	       irq_in,
    /* verilator lint_on UNUSEDSIGNAL */

    output reg	       busy,
    output wire [15:0] data_out,
    output reg	       cs_out,
    output reg	       sdi_out,
    output wire	       sck_out,
    output reg	       data_valid
    );
   
   reg internal_sck;
   reg [7:0] internal_data_in;
   /* verilator lint_off ASCRANGE */
   reg [0:2] data_counter;
   reg [0:3] data_in_counter;
   reg [0:15] reverse_data_out;
   /* verilator lint_on ASCRANGE */

   assign sck_out = internal_sck & ~cs_out; // sck is idle low
   assign data_out[15:0] = reverse_data_out[0:15];

   reg [2:0] current_state;
   reg [2:0] next_state;
   reg	     done;

   localparam s_IDLE = 3'b000;
   localparam s_ENABLE = 3'b001;
   localparam s_SEND = 3'b010;
   localparam s_WAIT = 3'b011;
   localparam s_RECEIVE = 3'b100;
   localparam s_DONE = 3'b101;

   // initial current_state = s_IDLE;
   // initial next_state = s_IDLE;

   always_ff @ (posedge sys_clk_1MHz or negedge rst_n) begin
      if (~rst_n) begin
	 current_state <= s_IDLE;
	 data_valid <= 1'b0;
	 internal_sck <= 1'b1;
	 sdi_out <= 1'b0;
	 reverse_data_out <= 16'b0;
	 internal_data_in <= 8'b0;
	 busy <= 1'b0;
	 data_counter <= 3'b0;
	 data_in_counter <= 4'b0;
	 cs_out <= 1'b1;
	 done <= 1'b0;
      end
      else begin
	 current_state <= next_state;
	 case (current_state)
	   s_IDLE: begin
	      internal_data_in <= 8'b0;
	      busy <= 1'b0;
	      data_counter <= 3'b0;
	      data_in_counter <= 4'b0;
	      cs_out <= 1'b1;
	      done <= 1'b0;
	   end
	   
	   s_ENABLE: begin
	      internal_data_in <= data_in;
	      busy <= 1'b1;
	      data_valid <= 1'b0;
	      cs_out <= 1'b0;
	   end
	   
	   s_SEND: begin
	      internal_sck <= !internal_sck;
	      if (internal_sck) begin
		 sdi_out <= internal_data_in[data_counter];
		 data_counter <= data_counter + 1'b1;
		 if (data_counter == 3'd7) begin
		    done <= 1'b1;
		 end
	      end
	   end
	   
	   s_WAIT: begin
	      cs_out <= 1'b0;
	      done <= 1'b0;
	      sdi_out <= 1'b0;
	      internal_sck <= 1'b0;
	   end
	   
	   s_RECEIVE: begin
	      internal_sck <= !internal_sck;
	      if (internal_sck) begin
		 reverse_data_out[data_in_counter] <= sdo_in;
		 data_in_counter <= data_in_counter + 1'b1;
		 if (data_in_counter == 4'd15) begin
		    done <= 1'b1;
		 end
	      end
	   end
	   
	   s_DONE: begin
	      data_valid <= 1'b1;
	      busy <= 1'b0;
	      cs_out <= 1'b1;
	      done <= 1'b0;
	   end
	   
	   default: begin
	      current_state <= s_IDLE;
	   end
	   
	 endcase
      end
   end

   always_comb begin
      next_state = current_state;
      case (current_state)
	s_IDLE: begin
	   if (en) begin
	      next_state = s_ENABLE;
	   end
	end
	
	s_ENABLE: begin
	   next_state = s_SEND;
	end
	
	s_SEND: begin
	   if (done) begin
	      next_state = s_WAIT;
	   end
	end
	
	s_WAIT: begin
	   next_state = s_RECEIVE;
	end
	
	s_RECEIVE: begin
	   if (done) begin
	      next_state = s_DONE;
	   end
	end
	
	s_DONE: begin
	   next_state = s_IDLE;
	end
	
	default: begin
	   next_state = s_IDLE;
	end
      endcase
   end   

endmodule // msp2807_touch_spi
`default_nettype wire

