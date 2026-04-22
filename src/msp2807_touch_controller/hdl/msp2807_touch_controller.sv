`default_nettype none
module msp2807_touch_controller 
  (
    input wire	     rst_n,
    input wire	     sys_clk_1MHz,
  
    input wire	     touch_sdo_in,
    input wire	     touch_irq_in,

    output wire	     touch_cs_out,
    output wire	     touch_sdi_out,
    output wire	     touch_sck_out,

    output reg [8:0] touch_x,
    output reg [7:0] touch_y,
    output wire	     touch_detected
   );

  reg touch_irq_sync_d;
  reg touch_irq_sync;

  always_ff @ (posedge sys_clk_1MHz or negedge rst_n) begin
    if (~rst_n) begin
      touch_irq_sync_d <= 1'b0;
      touch_irq_sync <= 1'b0;
    end
    else begin
      touch_irq_sync_d <= touch_irq_in;
      touch_irq_sync <= touch_irq_sync_d;
    end
  end

   reg touch_detected_delayed;
   assign touch_detected = touch_detected_delayed;
   reg touch_detected_internal; // Delay output of touch detection to allow math to propagate
   always_ff @ (posedge sys_clk_1MHz or negedge rst_n) begin
      if (~rst_n) begin
	 touch_detected_delayed <= 1'b0;
      end
      else begin
	 touch_detected_delayed <= touch_detected_internal;
      end
   end
   
   reg [11:0] touch_x_raw;
   reg [11:0] touch_y_raw;
   wire [8:0] touch_x_temp;
   wire [7:0] touch_y_temp;  

   assign touch_x_temp = 9'(((touch_x_raw - 90) * 320) / 1880); // Min raw x is 100, Max raw x is 1880
   assign touch_y_temp = 8'(((touch_y_raw - 150) * 240) / 1950); // Min raw y is 150, Max raw y is 1950
   always_ff @ (posedge sys_clk_1MHz or negedge rst_n) begin
      if (~rst_n) begin
	 touch_x <= '0;
	 touch_y <= '0;
      end
      else if (touch_detected_delayed) begin
	 touch_x <= touch_x_temp;
	 touch_y <= touch_y_temp;
      end
   end
   
   // assign touch_x = 9'((touch_x_raw * 320) >> 12); // Min raw x is 100, Max raw x is 1880
   // assign touch_y = 8'((touch_y_raw * 240) >> 12); // Min raw y is 150, Max raw y is 1950
   
   reg	      touch_en;
   reg [7:0]  touch_data_in;
   wire	      touch_busy;
   /* verilator lint_off UNUSEDSIGNAL */
   wire [15:0] touch_data_out;
   /* verilator lint_on UNUSEDSIGNAL */
   wire	       touch_data_valid;
   
   msp2807_touch_spi msp2807_touch_spi0
     (
      .rst_n(rst_n),
      .sys_clk_1MHz(sys_clk_1MHz),
      .en(touch_en),
      .data_in(touch_data_in),
      .sdo_in(touch_sdo_in),
      .irq_in(touch_irq_sync),
      .busy(touch_busy),
      .data_out(touch_data_out),
      .cs_out(touch_cs_out),
      .sdi_out(touch_sdi_out),
      .sck_out(touch_sck_out),
      .data_valid(touch_data_valid)
      );
   
   reg data_read = 1'b0;

   reg [23:0] delay_left = 24'b0;
   localparam CLK_FREQ_MHz = 1;

   // (* syn_preserve = 1, syn_encoding = "none" *) 
   reg [2:0] current_state;
   reg [2:0] next_state;

   localparam s_IDLE = 3'b000;
   localparam s_READ_X = 3'b001;
   localparam s_SET_X = 3'b010;
   localparam s_READ_Y = 3'b011;
   localparam s_SET_Y = 3'b100;

   reg [23:0] timeout = 24'b0; // Crude implementation of timeout tracking, implemented to fix weird state bug in this module, it did not fix it so reset logic was implemented instead

   always_ff @ (posedge sys_clk_1MHz or negedge rst_n) begin
      if (~rst_n) begin
	 current_state <= s_IDLE;
	 touch_en <= 1'b0;
	 touch_detected_internal <= 1'b0;
	 timeout <= 24'b0;
	 delay_left <= 24'b0;
	 touch_data_in <= 8'b0;
	 data_read <= 1'b0;
	 touch_x_raw <= 12'b0;
	 touch_y_raw <= 12'b0;
      end
      else begin
	 current_state <= next_state;
	 touch_en <= 1'b0;
	 touch_detected_internal <= 1'b0;
	 if (timeout > 24'b0) begin
	    timeout <= timeout - 1'b1;
	 end
	 if (delay_left > 24'b0) begin
	    delay_left <= delay_left - 1'b1; // Wait for delay to count down
	 end
	 else if (~touch_busy && ~touch_en) begin
	    case (current_state)
	      s_IDLE: begin
		 delay_left <= 24'b0;
		 touch_data_in <= 8'b0;
		 touch_en <= 1'b0;
		 data_read <= 1'b0;
	      end
	      
	      s_READ_X: begin
		 touch_data_in <= 8'h09; // Read x
		 touch_en <= 1'b1;
		 data_read <= 1'b0;
		 delay_left <= 24'(CLK_FREQ_MHz*50); // Approx 50us
		 timeout <= 24'(CLK_FREQ_MHz*150000);
	      end
	      
	      s_SET_X: begin
		 //if (touch_data_valid || ~timeout) begin
		 if (touch_data_valid) begin
		    timeout <= 24'b0;
		    touch_x_raw <= touch_data_out[15:4];
		    data_read <= 1'b1;
		 end
	      end
	      
	      s_READ_Y: begin
		 touch_data_in <= 8'h0B; // Read y
		 touch_en <= 1'b1;
		 data_read <= 1'b0;
		 delay_left <= 24'(CLK_FREQ_MHz*50); // Approx 50us
		 timeout <= 24'(CLK_FREQ_MHz*150000);
	      end
	      
	      s_SET_Y: begin
		 // if (touch_data_valid || ~timeout) begin
		 if (touch_data_valid) begin
		    timeout <= 24'b0;
		    touch_y_raw <= touch_data_out[15:4];
		    data_read <= 1'b1;
		    delay_left <= 24'(CLK_FREQ_MHz*150000); // Approx 150ms debouce delay
		    touch_detected_internal <= 1'b1;
		 end
	      end
	      
	      default: begin
		 current_state <= s_IDLE;
	      end
	    endcase
	 end
      end
   end

   always_comb begin
      next_state = current_state;
      case (current_state)
	s_IDLE: begin
	   if (~touch_busy && ~touch_en && ~touch_irq_sync) begin
	      next_state = s_READ_X;
	   end
	end
	
	s_READ_X: begin
	   next_state = s_SET_X;
	end
	
	s_SET_X: begin
	   if (data_read) begin
	      next_state = s_READ_Y;
	   end
	end
	
	s_READ_Y: begin
	   next_state = s_SET_Y;
	end
	
	s_SET_Y: begin
	   if (data_read) begin
	      next_state = s_IDLE;
	   end
	end
	
	default: begin
	   next_state = s_IDLE;
	end
      endcase
   end

endmodule // msp2807_touch_controller
`default_nettype wire

