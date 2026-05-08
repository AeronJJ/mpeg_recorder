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

   input wire                          running,   // Connect to init_done
   output reg                          packet_done_pulse,
   
   input wire                          mpeg_clk_6MHz,
   // input wire                          mpeg_sync, // Used to start reading and guarantee alignment

   output wire                         mpeg_clk_6MHz_out,
   output wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_out,
   output reg                          mpeg_sync_out,
   output reg                          mpeg_valid_out,

   input wire [31:0]                   mpeg_sync_clk_cycle_count
   );

  // Delay sync_out and valid_out //
  wire mpeg_sync_out_d;
  wire mpeg_valid_out_d;
  always_ff @ (negedge mpeg_clk_6MHz_out or negedge rst_n) begin
    if (~rst_n) begin
      mpeg_sync_out <= 1'b0;
      mpeg_valid_out <= 1'b0;
    end
    else begin
      mpeg_sync_out <= mpeg_sync_out_d;
      mpeg_valid_out <= mpeg_valid_out_d;
    end
  end
  // // 
  
  // Create packet buffers //
  wire                         r_en;
  wire [MPEG_DATA_WIDTH - 1:0] r_data_mem0;
  wire [MPEG_DATA_WIDTH - 1:0] r_data_mem1;

  assign mpeg_data_8_out = pb_r_sel ? r_data_mem0 : r_data_mem1; // Read mem0 when mem1 is being written, and vice-versa

  packet_buffer_playback 
    #(
      .PACKET_LENGTH_BYTES(MPEG_PACKET_LENGTH_BYTES),
      .WRITE_DATA_WIDTH(MPEG_MEM_LENGTH),
      .READ_DATA_WIDTH(MPEG_DATA_WIDTH)
      )
  mpeg_packet_buffer_pb0
    (
     .rst_n(rst_n),
     
     .w_clk(sys_clk),
     .w_en(pb0_w_en),
     .w_addr(pb_w_addr),
     .w_data(pb_w_data),
     
     .r_clk(~mpeg_clk_6MHz),
     .r_en(pb_r_sel & r_en),
     .r_addr(mpeg_controller_addr),
     .r_data(r_data_mem0)
     );

  packet_buffer_playback 
    #(
      .PACKET_LENGTH_BYTES(MPEG_PACKET_LENGTH_BYTES),
      .WRITE_DATA_WIDTH(MPEG_MEM_LENGTH),
      .READ_DATA_WIDTH(MPEG_DATA_WIDTH)
      )
  mpeg_packet_buffer_pb1
    (
     .rst_n(rst_n),
     
     .w_clk(sys_clk),
     .w_en(pb1_w_en),
     .w_addr(pb_w_addr),
     .w_data(pb_w_data),
     
     .r_clk(~mpeg_clk_6MHz),
     .r_en(~pb_r_sel & r_en),
     .r_addr(mpeg_controller_addr),
     .r_data(r_data_mem1)
     );

  // MPEG controller//

  wire [$clog2(MPEG_PACKET_LENGTH_BYTES) - 1:0] mpeg_controller_addr;

  /* verilator lint_off PINCONNECTEMPTY */
  mpeg_controller
    #(.PACKET_LENGTH(MPEG_PACKET_LENGTH_BYTES))
  mpeg_controller_0
    (
     .rst_n(rst_n),
     .mpeg_clk_6MHz(mpeg_clk_6MHz),
     .start(running & mpeg_sync),
     .r_en(r_en),
     .r_addr(mpeg_controller_addr),
     .mpeg_sync_out(mpeg_sync_out_d),
     .mpeg_valid_out(mpeg_valid_out_d),
     .word_r_en()
     );

  assign mpeg_clk_6MHz_out = mpeg_clk_6MHz;
  // //

  // Generate packet done signal //
  wire packet_done;
  wire packet_done_r;
  reg  packet_done_d;
  assign packet_done = (packet_done_r ^ packet_done_d) & packet_done_r;
  assign packet_done_r = (mpeg_controller_addr[7:2] == MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH)) ? 1'b1 : 1'b0;
  always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin //
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
  always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin
    if (~rst_n) begin
      pb_r_sel <= 1'b0;
    end
    else if (~running) begin
      pb_r_sel <= 1'b1;
    end
    else if (packet_done_pulse) begin
      pb_r_sel <= ~pb_r_sel;
    end
  end
  // //

  // Generate MPEG sync pulse //
  wire mpeg_sync;
  mpeg_sync_gen mpeg_sync_gen_inst
    (
     .rst_n(rst_n),
     .sys_clk(sys_clk),
     .mpeg_clk(mpeg_clk_6MHz),
     .en(running),
     .clk_cycles_count(mpeg_sync_clk_cycle_count),
     .mpeg_sync(mpeg_sync)
     );
  // //
  
endmodule // mpeg_playback
`default_nettype wire

