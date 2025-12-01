`default_nettype none
module mpeg_recorder 
  #(
    parameter MPEG_DATA_WIDTH = 8,
    parameter MPEG_MEM_WIDTH = 4, // Bytes
    parameter MPEG_MEM_LENGTH = MPEG_DATA_WIDTH * MPEG_MEM_WIDTH,
    parameter MPEG_ADDR_WIDTH = 6,
    parameter MPEG_PACKET_LENGTH = 188/MPEG_MEM_WIDTH
    )
   (
    input wire				rst_n,

    input wire				mpeg_clk_6MHz,
    input wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8,
    input wire				mpeg_sync,
    input wire				mpeg_valid,

    input wire				sys_clk_40MHz,

    input wire				start,
    input wire				stop,

    output wire				mpeg_clk_6MHz_out,
    output wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_out,
    output wire [MPEG_MEM_LENGTH - 1:0]	r_data,
    output wire				mpeg_sync_out,
    output reg				mpeg_valid_out
    );

   assign mpeg_clk_6MHz_out = mpeg_clk_6MHz;
   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 mpeg_valid_out <= 1'b0;
      end
      else if (start) begin
	 mpeg_valid_out <= 1'b1;
      end
      else if (stop) begin
	 mpeg_valid_out <= 1'b0;
      end
   end
   // 1.5 MHz clock gen for 32 bit data //
   reg clk_3MHz;
   reg clk_1M5Hz;
   // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
   //    if (~rst_n) begin
   // 	 clk_3MHz <= 1'b0;
   //    end
   //    else if (mpeg_sync) begin
   // 	 clk_3MHz <= 1'b1;
   //    end
   //    else begin
   // 	 clk_3MHz <= ~clk_3MHz;
   //    end
   // end

   // always_ff @ (posedge clk_3MHz or negedge rst_n) begin
   //    if (~rst_n) begin
   // 	 clk_1M5Hz <= 1'b0;
   //    end
   //    else if (mpeg_sync) begin
   // 	 clk_1M5Hz <= 1'b1;
   //    end
   //    else begin
   // 	 clk_1M5Hz <= ~clk_1M5Hz;
   //    end
   // end // always_ff @ (posedge clk_3MHz or negedge rst_n)

   always_ff @ (posedge mpeg_clk_6MHz or posedge mpeg_sync) begin
      if (mpeg_sync) begin
	 clk_3MHz <= 1'b1;
      end
      else begin
	 clk_3MHz <= ~clk_3MHz;
      end
   end

   always_ff @ (posedge clk_3MHz or posedge mpeg_sync) begin
      if (mpeg_sync) begin
	 clk_1M5Hz <= 1'b1;
      end
      else begin
	 clk_1M5Hz <= ~clk_1M5Hz;
      end
   end
   
   // //

   // Buffer 4 bytes of input mpeg data //
   wire [MPEG_MEM_LENGTH - 1:0] mpeg_data_32_packed;

   byte_packer 
     #(.NUM_WRITE_BITS(MPEG_DATA_WIDTH), .NUM_WRITES(MPEG_MEM_WIDTH)) 
   mpeg_byte_packer 
     (
      .rst_n(rst_n),
      .w_clk(mpeg_clk_6MHz),
      .w_data(mpeg_data_8),
      .en(running),
      .sync(mpeg_sync),
      .data_packed(mpeg_data_32_packed)
      );
   
   // //

   // Generate write address //
   wire packet_done;
   reg	w_en_mem0;
   wire	r_en_mem0;
   assign r_en_mem0 = ~w_en_mem0;
   
   assign packet_done = (w_addr == MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH - 1)) ? 1'b1 : 1'b0;
   // wire [MPEG_ADDR_WIDTH - 1:0] w_addr;
   // reg [MPEG_ADDR_WIDTH - 1 + 2:0] w_addr_tmp;
   // assign w_addr = w_addr_tmp[MPEG_ADDR_WIDTH - 1 + 2:2];
   // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
   //    if (~rst_n) begin
   // 	 w_addr_tmp <= '0;
   // 	 w_en_mem0 <= 1'b1;
   //    end
   //    else if (mpeg_sync) begin
   // 	 w_addr_tmp <= '0;
   // 	 w_en_mem0 <= ~w_en_mem0;
   //    end
   //    else if (running) begin
   // 	 w_addr_tmp <= w_addr_tmp + 1'b1;
   //    end
   //    else begin
   // 	 w_addr_tmp <= '0;
   // 	 w_en_mem0 <= 1'b1;
   //    end
   // end // always_ff @ (posedge clk_1M5Hz or negedge rst_n)
   // reg [MPEG_ADDR_WIDTH - 1:0] w_addr;
   // reg [MPEG_ADDR_WIDTH - 1:0] w_addr_tmp;
   // always_ff @ (posedge clk_1M5Hz or posedge mpeg_sync) begin
   //    if (mpeg_sync) begin
   // 	 w_addr_tmp <= MPEG_ADDR_WIDTH'(46);
   // 	 w_en_mem0 <= ~w_en_mem0;
   // 	 w_addr <= '0;
   //    end
   //    else if (running) begin
   // 	 if (w_addr_tmp == MPEG_ADDR_WIDTH'(46)) begin
   // 	    w_addr <= MPEG_ADDR_WIDTH'(1);
   // 	    w_addr_tmp <= '0;
   // 	    // w_en_mem0 <= ~w_en_mem0;
   // 	 end
   // 	 else begin
   // 	    w_addr <= w_addr + 1'b1;
   // 	    // w_addr <= w_addr_tmp;
   // 	 end
   //    end
   //    else begin
   // 	 w_addr <= '0;
   // 	 w_en_mem0 <= 1'b1;
   // 	 // w_addr <= '0;
   //    end
   // end // always_ff @ (posedge clk_1M5Hz or negedge rst_n)

   
   reg [MPEG_ADDR_WIDTH - 1:0] w_addr;
   reg [MPEG_ADDR_WIDTH - 1 + 2:0] w_addr_tmp;
   // assign w_addr = w_addr_tmp[MPEG_ADDR_WIDTH - 1 + 2:2];

   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 w_addr_tmp <= '0;
	 // w_en_mem0 <= ~w_en_mem0;
	 w_addr <= '0;
      end
      else if (running) begin
	 if (mpeg_sync) begin
	    w_addr_tmp <= '0;
	    w_addr <= '0;
	 end
	 else begin
	    w_addr_tmp <= w_addr_tmp + 1'b1;
	    w_addr <= w_addr_tmp[MPEG_ADDR_WIDTH - 1 + 2:2];
	 end
      end
   end // always_ff @ (negedge mpeg_clk_6MHz or posedge mpeg_sync)

   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 w_en_mem0 <= 1'b0;
      end
      else if (mpeg_sync && running) begin
	 w_en_mem0 <= ~w_en_mem0;
      end
      else if (~running) begin
	 w_en_mem0 <= 1'b0;
      end
   end
   // //

   // Create packet buffers //
   // reg w_en_mem0;
   // reg w_en_mem1;

   wire [MPEG_ADDR_WIDTH - 1:0] r_addr;
   // wire				r_en_mem0;
   // wire				r_en_mem1;

   // assign r_en_mem0 = ~w_en_mem0;
   // assign r_en_mem1 = ~w_en_mem1;
   
   wire [MPEG_MEM_LENGTH - 1:0] r_data_mem0;
   wire [MPEG_MEM_LENGTH - 1:0] r_data_mem1;

   reg				r_data_switch;
   
   always_ff @ (negedge clk_1M5Hz or negedge rst_n) begin
      if (~rst_n) begin
	 r_data_switch <= 1'b0;
      end
      else if (running) begin
	 r_data_switch <= r_en_mem0;
      end
   end
   assign r_data = r_data_switch ? r_data_mem0 : r_data_mem1; // Read mem0 when mem1 is being written, and vice-versa
   
   packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_mem0
     (
      .rst_n(rst_n),
      
      // .w_clk(mpeg_clk_6MHz),
      .w_clk(clk_1M5Hz),
      .w_en(w_en_mem0),
      .w_addr(w_addr),
      .w_data(mpeg_data_32_packed),
      
      // .r_clk(sys_clk_40MHz),
      // .r_clk(mpeg_clk_6MHz),
      .r_clk(clk_1M5Hz),
      .r_en(r_en_mem0),
      .r_addr(r_addr),
      .r_data(r_data_mem0)
      );
	 
   packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_mem1
     (
      .rst_n(rst_n),
      
      // .w_clk(mpeg_clk_6MHz),
      .w_clk(clk_1M5Hz),
      .w_en(~w_en_mem0),
      .w_addr(w_addr),
      .w_data(mpeg_data_32_packed),
      
      // .r_clk(sys_clk_40MHz),
      // .r_clk(mpeg_clk_6MHz),
      .r_clk(clk_1M5Hz),
      .r_en(~r_en_mem0),
      .r_addr(r_addr),
      .r_data(r_data_mem1)
      );
   // //

   // Read Address Gen //
   wire r_done;
   mpeg_read_addr_gen #(.MPEG_ADDR_WIDTH(MPEG_ADDR_WIDTH), .MPEG_PACKET_LENGTH(MPEG_PACKET_LENGTH)) mpeg_read_addr_gen
     (
      .rst_n(rst_n),
      .r_clk(clk_1M5Hz),
      .en(running),
      .start(packet_done),
      .r_addr(r_addr),
      .r_end(r_done)
      );

   // Unpack data //
   // wire mpeg_sync_out;
   byte_unpacker
     #(.NUM_READ_BITS(), .NUM_READS())
   mpeg_byte_unpacker
     (
      .rst_n(rst_n),
      .w_data(r_data),
      .r_clk(mpeg_clk_6MHz),
      .r_data(mpeg_data_8_out),
      .en(running),
      .sync(r_addr == MPEG_ADDR_WIDTH'(1)),
      .mpeg_sync(mpeg_sync_out)
      );
   
   // //

   // wire [7:0] mpeg_data_8_out;
   
   // Generate new sync pulse //
   // reg [1:0] unpacked_addr;
   // reg mpeg_sync_out;
   // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
   //    if (~rst_n) begin
   // 	 mpeg_sync_out <= 1'b0;
   //    end
   //    else if (running) begin
   // 	 if (r_addr == MPEG_ADDR_WIDTH'(1) && unpacked_addr == '0) begin
   // 	    mpeg_sync_out <= 1'b1;
   // 	 end
   // 	 else begin
   // 	    mpeg_sync_out <= 1'b0;
   // 	 end
   //    end
   //    else begin
   // 	 mpeg_sync_out <= 1'b0;
   //    end
   // end
   // // //
   
   // //
   
   // Finite State Machine for 6MHz domain control //
   reg running;
   reg en_running;

   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 running <= 1'b0;
      end
      else if (en_running && mpeg_sync) begin
	 running <= 1'b1;
      end
      else if (~en_running) begin
	 running <= 1'b0;
      end
   end // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n)

   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 en_running <= 1'b0;
      end
      else if (start) begin
	 en_running <= 1'b1;
      end
      else if (stop) begin
	 en_running <= 1'b0;
      end
   end
   
   localparam N_STATES = 3;

   localparam s_IDLE = N_STATES'(0);
   localparam s_WAIT_FOR_SYNC = N_STATES'(1);
   localparam s_WRITE_MEM0 = N_STATES'(2);
   localparam s_WRITE_MEM1 = N_STATES'(3);
   localparam s_DONE = N_STATES'(4);
   
   reg [N_STATES - 1:0] current_state;
   reg [N_STATES - 1:0] next_state;

   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 current_state <= s_IDLE;
      end
      else begin
	 current_state <= next_state;
	 case (current_state)
	   s_IDLE: begin
	      // en_running <= 1'b0;
	   end

	   s_WAIT_FOR_SYNC: begin
	      // en_running <= 1'b1;	      
	   end

	   s_WRITE_MEM0: begin
	      // en_running <= 1'b1;
	      // w_en_mem0 <= 1'b1;
	      // w_en_mem1 <= 1'b0;
	   end

	   s_WRITE_MEM1: begin
	      // en_running <= 1'b1;
	      // w_en_mem0 <= 1'b0;
	      // w_en_mem1 <= 1'b1;	      
	   end

	   s_DONE: begin
	      // en_running <= 1'b0;
	   end

	   default: begin
	      // en_running <= 1'b0;
	   end
	 endcase // case (current_state)
      end
   end // always_ff @ (posedge clk_1M5Hz or negedge rst_n)
   
   always_comb begin
      next_state = current_state;
      case (current_state)
	s_IDLE: begin
	   if (start) begin
	      next_state = s_WAIT_FOR_SYNC;
	   end
	end

	s_WAIT_FOR_SYNC: begin
	   if (mpeg_sync) begin
	      next_state = s_WRITE_MEM0;
	   end
	end

	s_WRITE_MEM0: begin
	   if (packet_done) begin
	      next_state = s_WRITE_MEM1;
	   end
	   else if (stop) begin
	      next_state = s_DONE;
	   end
	end

	s_WRITE_MEM1: begin
	   if (packet_done) begin
	      next_state = s_WRITE_MEM0;
	   end
	   else if (stop) begin
	      next_state = s_DONE;
	   end
	end

	s_DONE: begin
	   next_state = s_IDLE;
	end

	default: begin
	   next_state = s_IDLE;
	end
      endcase // case (current_state)
   end // always_comb
   // //
   
endmodule // mpeg_recorder
`default_nettype wire
  
