`default_nettype none
module mpeg_recorder 
  #(
    parameter MPEG_DATA_WIDTH = 8,
    parameter MPEG_MEM_WIDTH = 4, // Bytes
    parameter MPEG_MEM_LENGTH = MPEG_DATA_WIDTH * MPEG_MEM_WIDTH,
    parameter MPEG_ADDR_WIDTH = 6,
    parameter MPEG_PACKET_LENGTH_BYTES = 188,
    parameter MPEG_PACKET_LENGTH = MPEG_PACKET_LENGTH_BYTES/MPEG_MEM_WIDTH
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
   

   // Buffer 4 bytes of input mpeg data //
   wire [MPEG_MEM_LENGTH - 1:0] mpeg_data_32_packed;
   wire				word_w_en;
   
   byte_packer 
     #(.NUM_WRITE_BITS(MPEG_DATA_WIDTH), .NUM_WRITES(MPEG_MEM_WIDTH)) 
   mpeg_byte_packer 
     (
      .rst_n(rst_n),
      .w_clk(mpeg_clk_6MHz),
      .w_data(mpeg_data_8),
      .en(running & mpeg_valid),
      .w_en(word_w_en),
      .data_packed(mpeg_data_32_packed)
      );
   
   // //

   // Generate write address //
   wire packet_done;
   wire	packet_done_r;
   reg	packet_done_d;
   assign packet_done = (packet_done_r ^ packet_done_d) & packet_done_r;
   assign packet_done_r = (w_addr == MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH)) ? 1'b1 : 1'b0;
   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 packet_done_d <= 1'b0;
      end
      else begin
	 packet_done_d <= packet_done_r;
      end
   end

   reg packet_done_pulse;
   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 packet_done_pulse <= 1'b0;
      end
      else begin
	 packet_done_pulse <= packet_done;
      end
   end
   
   reg	w_en_mem0;
   wire	r_en_mem0;
   assign r_en_mem0 = ~w_en_mem0;
   
   reg [MPEG_ADDR_WIDTH - 1:0] w_addr;
   reg [MPEG_ADDR_WIDTH - 1 + 2:0] w_addr_tmp;

   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 w_addr_tmp <= '0;
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
      else if (packet_done && running) begin
	 w_en_mem0 <= ~w_en_mem0;
      end
      else if (~running) begin
	 w_en_mem0 <= 1'b0;
      end
   end
   // //

   // Create packet buffers //
   
   wire [MPEG_MEM_LENGTH - 1:0] r_data_mem0;
   wire [MPEG_MEM_LENGTH - 1:0] r_data_mem1;

   reg				r_data_switch;
   
   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
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
      
      .w_clk(mpeg_clk_6MHz),
      // .w_clk(clk_1M5Hz),
      .w_en(w_en_mem0 & word_w_en),
      .w_addr(w_addr),
      .w_data(mpeg_data_32_packed),
      
      // .r_clk(sys_clk_40MHz),
      .r_clk(mpeg_clk_6MHz),
      // .r_clk(clk_1M5Hz),
      .r_en(r_en_mem0 & word_r_en),
      .r_addr(mpeg_controller_addr[7:2]), // TODO: Parameterise
      .r_data(r_data_mem0)
      );
	 
   packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_mem1
     (
      .rst_n(rst_n),
      
      .w_clk(mpeg_clk_6MHz),
      // .w_clk(clk_1M5Hz),
      .w_en(~w_en_mem0 & word_w_en),
      .w_addr(w_addr),
      .w_data(mpeg_data_32_packed),
      
      // .r_clk(sys_clk_40MHz),
      .r_clk(mpeg_clk_6MHz),
      // .r_clk(clk_1M5Hz),
      .r_en(~r_en_mem0 & word_r_en),
      .r_addr(mpeg_controller_addr[7:2]),
      .r_data(r_data_mem1)
      );
   // //

   // Byte unpacker and controller//

   // Unpack data //
   byte_unpacker
     #(.NUM_READ_BITS(), .NUM_READS())
   mpeg_byte_unpacker
     (
      .rst_n(rst_n),
      .w_data(r_data),
      .r_clk(mpeg_clk_6MHz),
      .r_addr(mpeg_controller_addr_d[1:0]),
      .r_data(mpeg_data_8_out),
      .en(byte_unpacker_en)
      );

   wire						 byte_unpacker_en;
   
   wire [$clog2(MPEG_PACKET_LENGTH_BYTES) - 1:0] mpeg_controller_addr;
   reg [$clog2(MPEG_PACKET_LENGTH_BYTES) - 1:0]	 mpeg_controller_addr_d;

   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
	 mpeg_controller_addr_d <= '0;
      end
      else begin
	 mpeg_controller_addr_d <= mpeg_controller_addr;
      end
   end

   wire word_r_en;
   
   mpeg_controller
     #(.PACKET_LENGTH(MPEG_PACKET_LENGTH_BYTES))
   mpeg_controller_0
     (
      .rst_n(rst_n),
      .mpeg_clk_6MHz(mpeg_clk_6MHz),
      .packet_done_pulse(running & packet_done_pulse),
      .r_en(byte_unpacker_en),
      .r_addr(mpeg_controller_addr),
      .mpeg_sync_out(mpeg_sync_out),
      .mpeg_valid_out(mpeg_valid_out),
      .word_r_en(word_r_en)
      );
   
   // //
   
   // running control //
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
   
endmodule // mpeg_recorder
`default_nettype wire
  
