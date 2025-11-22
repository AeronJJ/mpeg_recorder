`default_nettype none
module mpeg_recorder 
  #(
    parameter MPEG_DATA_WIDTH = 8,
    parameter MPEG_MEM_WIDTH = 4, // Bytes
    parameter MPEG_MEM_LENGTH = MPEG_DATA_WIDTH * MPEG_MEM_WIDTH,
    parameter MPEG_ADDR_WIDTH = 8,
    parameter MPEG_PACKET_LENGTH = 188
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

    output wire [MPEG_MEM_LENGTH - 1:0]	r_data
    );

   // Buffer 4 bytes of input mpeg data //
   reg [MPEG_DATA_WIDTH - 1:0] mpeg_data_32 [MPEG_MEM_WIDTH - 1:0];
   reg [1:0]		       mpeg_data_32_addr; // 2 bits = 4 addresses, 4*8 = 32 bits

   wire [MPEG_MEM_LENGTH - 1:0] mpeg_data_32_packed = {mpeg_data_32[3], mpeg_data_32[2], mpeg_data_32[1], mpeg_data_32[0]};
   
   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 mpeg_data_32[0] <= '0;
	 mpeg_data_32[1] <= '0;
	 mpeg_data_32[2] <= '0;
	 mpeg_data_32[3] <= '0;
	 mpeg_data_32_addr <= '0;
      end
      else if (running) begin
	 mpeg_data_32[mpeg_data_32_addr] <= mpeg_data_8;
	 mpeg_data_32_addr <= mpeg_data_32_addr + 1'b1; // Force overflow
      end
      else begin
	 mpeg_data_32_addr <= '0;
      end
   end // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n)
   // //

   // Generate write address //
   wire packet_done;
   assign packet_done = (w_addr == MPEG_ADDR_WIDTH'(187)) ? 1'b1 : 1'b0;
   reg [MPEG_ADDR_WIDTH - 1:0] w_addr;
   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 w_addr <= '0;
      end
      else if (packet_done) begin
	 w_addr <= '0;
      end
      else if (running) begin
	 w_addr <= w_addr + 1'b1;
      end
      else begin
	 w_addr <= '0;
      end
   end
   // //

   // Create packet buffers //
   reg w_en_mem0;
   reg w_en_mem1;

   wire [MPEG_ADDR_WIDTH - 1:0] r_addr;
   wire				r_en_mem0;
   wire				r_en_mem1;

   assign r_en_mem0 = ~w_en_mem0;
   assign r_en_mem1 = ~w_en_mem1;
   
   wire [MPEG_MEM_LENGTH - 1:0] r_data_mem0;
   wire [MPEG_MEM_LENGTH - 1:0] r_data_mem1;
   assign r_data = w_en_mem1 ? r_data_mem0 : r_data_mem1; // Read mem0 when mem1 is being written, and vice-versa
   
   packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_mem0
     (
      .rst_n(rst_n),
      
      .w_clk(mpeg_clk_6MHz),
      .w_en(w_en_mem0),
      .w_addr(w_addr),
      .w_data(mpeg_data_32_packed),
      
      // .r_clk(sys_clk_40MHz),
      .r_clk(mpeg_clk_6MHz),
      .r_en(r_en_mem0),
      .r_addr(r_addr),
      .r_data(r_data_mem0)
      );
	 
   packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_mem1
     (
      .rst_n(rst_n),
      
      .w_clk(mpeg_clk_6MHz),
      .w_en(w_en_mem1),
      .w_addr(w_addr),
      .w_data(mpeg_data_32_packed),
      
      // .r_clk(sys_clk_40MHz),
      .r_clk(mpeg_clk_6MHz),
      .r_en(r_en_mem1),
      .r_addr(r_addr),
      .r_data(r_data_mem1)
      );
   // //

   // Read Address Gen //
   wire r_done;
   mpeg_read_addr_gen #(.MPEG_ADDR_WIDTH(MPEG_ADDR_WIDTH), .MPEG_PACKET_LENGTH(MPEG_PACKET_LENGTH)) mpeg_read_addr_gen
     (
      .rst_n(rst_n),
      .r_clk(mpeg_clk_6MHz),
      .en(running),
      .start(packet_done),
      .r_addr(r_addr),
      .r_end(r_done)
      );
   
   // //
   
   // Finite State Machine for 6MHz domain control //
   reg running;
   
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
	      running <= 1'b0;
	   end

	   s_WAIT_FOR_SYNC: begin
	      running <= 1'b0;	      
	   end

	   s_WRITE_MEM0: begin
	      running <= 1'b1;
	      w_en_mem0 <= 1'b1;
	      w_en_mem1 <= 1'b0;
	   end

	   s_WRITE_MEM1: begin
	      running <= 1'b1;
	      w_en_mem0 <= 1'b0;
	      w_en_mem1 <= 1'b1;	      
	   end

	   s_DONE: begin
	      running <= 1'b0;
	   end

	   default: begin
	      running <= 1'b0;
	   end
	 endcase // case (current_state)
      end
   end
   
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
   end
   // //
   

endmodule // mpeg_recorder
`default_nettype wire
  
