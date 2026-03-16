`default_nettype none
module mpeg_playback 
  #(
    parameter MPEG_DATA_WIDTH = 8,
    parameter MPEG_MEM_WIDTH = 4, // Bytes
    parameter MPEG_MEM_LENGTH = MPEG_DATA_WIDTH * MPEG_MEM_WIDTH,
    parameter MPEG_ADDR_WIDTH = 6,
    parameter MPEG_PACKET_LENGTH_BYTES = 188,
    parameter MPEG_PACKET_LENGTH = MPEG_PACKET_LENGTH_BYTES/MPEG_MEM_WIDTH
    )
  (
   input wire                          sys_clk,
   input wire                          rst_n,

   input wire [MPEG_MEM_LENGTH - 1:0]  pb_w_data,
   input wire [MPEG_ADDR_WIDTH - 1:0]  pb_w_addr,
   input wire                          pb0_w_en,
   input wire                          pb1_w_en,

   input wire                          running, // Connect to init_done
   output reg                          packet_done_pulse,
   
   input wire                          mpeg_clk_6MHz,
   input wire                          mpeg_sync, // Used to start reading and guarantee alignment

   output wire                         mpeg_clk_6MHz_out,
   output wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_out,
   output wire                         mpeg_sync_out,
   output wire                         mpeg_valid_out
   );
  
  // Create packet buffers //
  wire [MPEG_MEM_LENGTH - 1:0] r_data;
  wire [MPEG_MEM_LENGTH - 1:0] r_data_mem0;
  wire [MPEG_MEM_LENGTH - 1:0] r_data_mem1;

  reg                          r_data_switch;
  
  always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin //
    if (~rst_n) begin
      r_data_switch <= 1'b0;
    end
    else if (running) begin
      r_data_switch <= r_en_mem0;
    end
  end
  assign r_data = r_data_switch ? r_data_mem0 : r_data_mem1; // Read mem0 when mem1 is being written, and vice-versa
  
  packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_pb0
    (
     .rst_n(rst_n),
     
     .w_clk(sys_clk),
     .w_en(pb0_w_en),
     .w_addr(pb_w_addr),
     .w_data(pb_w_data),
     
     .r_clk(mpeg_clk_6MHz),
     .r_en(pb_r_sel & word_r_en),
     .r_addr(mpeg_controller_addr[7:2]), // TODO: Parameterise
     .r_data(r_data_mem0)
     );
  
  packet_buffer #(.ADDR_WIDTH(MPEG_ADDR_WIDTH), .MEM_WIDTH(MPEG_MEM_LENGTH)) mpeg_packet_buffer_pb1
    (
     .rst_n(rst_n),
     
     .w_clk(sys_clk),
     .w_en(pb1_w_en),
     .w_addr(pb_w_addr),
     .w_data(pb_w_data),
     
     .r_clk(mpeg_clk_6MHz),
     .r_en(~pb_r_sel & word_r_en),
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

  wire byte_unpacker_en;
  
  wire [$clog2(MPEG_PACKET_LENGTH_BYTES) - 1:0] mpeg_controller_addr;
  reg [$clog2(MPEG_PACKET_LENGTH_BYTES) - 1:0]  mpeg_controller_addr_d;
  
  always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin //
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
     .packet_done_pulse(running & mpeg_sync),
     .r_en(byte_unpacker_en),
     .r_addr(mpeg_controller_addr),
     .mpeg_sync_out(mpeg_sync_out),
     .mpeg_valid_out(mpeg_valid_out),
     .word_r_en(word_r_en)
     );
  
  // //

  // Generate packet done signal //
  wire packet_done;
  wire packet_done_r;
  reg  packet_done_d;
  assign packet_done = (packet_done_r ^ packet_done_d) & packet_done_r;
  assign packet_done_r = (mpeg_controller_addr[7:2] == MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH)) ? 1'b1 : 1'b0;
  always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin //
    if (~rst_n) begin
      packet_done_d <= 1'b0;
    end
    else begin
      packet_done_d <= packet_done_r;
    end
  end

  always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin //
    if (~rst_n) begin
      packet_done_pulse <= 1'b0;
    end
    else begin
      packet_done_pulse <= packet_done;
    end
  end
  // //

  // Select packet buffer to read //
  reg pb_r_sel;
  always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
    if (~rst_n) begin
      pb_r_sel <= 1'b0;
    end
    if (packet_done) begin
      pb_r_sel <= ~pb_r_sel;
    end
  end
  // //
  
endmodule // mpeg_playback
`default_nettype wire

