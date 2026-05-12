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
   input wire                          rst_n,
  
   input wire                          mpeg_clk_6MHz,
   input wire [MPEG_DATA_WIDTH - 1:0]  mpeg_data_8,
   input wire                          mpeg_sync,
   input wire                          mpeg_valid,

   input wire                          sys_clk,

   input wire                          start,
   input wire                          stop,
   
   output wire [MPEG_MEM_LENGTH - 1:0] r_data_32,
   input wire [MPEG_ADDR_WIDTH - 1:0]  r_addr,
   input wire                          r_en,
   output reg                          packet_done_out,

   output wire                         recording
   );

  // Detect mpeg positive edge //
  wire mpeg_clk_pos_edge = (mpeg_clk_d2 ^ mpeg_clk_d1) & mpeg_clk_d1;
  reg mpeg_clk_d0;
  reg mpeg_clk_d1;
  reg mpeg_clk_d2;
  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      mpeg_clk_d0 <= 1'b0;
      mpeg_clk_d1 <= 1'b0;
      mpeg_clk_d2 <= 1'b0;
    end
    else begin
      mpeg_clk_d0 <= mpeg_clk_6MHz;
      mpeg_clk_d1 <= mpeg_clk_d0;
      mpeg_clk_d2 <= mpeg_clk_d1;
    end
  end // always_ff @ (posedge sys_clk or negedge rst_n)

  // //

  assign recording = running_sys;
  
  // Packet done signals //
  wire packet_done;
  wire packet_done_r;
  reg  packet_done_d;
  
  assign packet_done = (packet_done_r ^ packet_done_d) & packet_done_r;
  assign packet_done_r = (w_addr == 8'd187) ? 1'b1 : 1'b0;
  
  always_ff @ (posedge sys_clk or negedge rst_n) begin 
    if (~rst_n) begin
      packet_done_d <= 1'b0;
    end
    else if (mpeg_clk_pos_edge) begin
      packet_done_d <= packet_done_r;
    end
  end

  reg packet_done_out_delay;
  always_ff @ (posedge sys_clk or negedge rst_n) begin 
    if (~rst_n) begin
      packet_done_out_delay <= 1'b0;
    end
    else if (mpeg_clk_pos_edge) begin
      packet_done_out_delay <= packet_done;
    end
  end

  // //

  // Outsync packet_done //
  reg packet_done_out_d;
  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      packet_done_out <= 1'b0;
      packet_done_out_d <= 1'b0;
    end
    else begin
      packet_done_out <= packet_done_out_d;
      packet_done_out_d <= packet_done_out_delay;
    end
  end
  // //

  // Sync w_en_mem0 into sys_clk //
  reg r_en_mem0;
  reg r_en_mem0_r;

  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      r_en_mem0_r <= 1'b0;
      r_en_mem0 <= 1'b0;
    end
    else begin
      r_en_mem0_r <= ~w_en_mem0;
      r_en_mem0 <= r_en_mem0_r;
    end
  end
  // //
  
  // Delay mpeg_data by one clock cycle //
  reg [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_d;
  reg                         mpeg_valid_d;
  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      mpeg_data_8_d <= '0;
      mpeg_valid_d <= 1'b0;
    end
    else if (mpeg_clk_pos_edge) begin
      mpeg_data_8_d <= mpeg_data_8;
      mpeg_valid_d <= mpeg_valid;
    end
  end
  // //

  // Generate write address for packet buffer //
  reg [MPEG_ADDR_WIDTH - 1 + 2:0] w_addr;
  reg                             packet_started;  

  always_ff @ (posedge sys_clk or negedge rst_n) begin //
    if (~rst_n) begin
      w_addr <= '0;
      packet_started <= 1'b0;
    end
    else if (running && mpeg_clk_pos_edge) begin
      if (mpeg_sync && ~packet_started) begin
	w_addr <= '0;
	packet_started <= 1'b1;
      end
      else if (packet_done) begin
	packet_started <= 1'b0;
      end
      else if (packet_started && mpeg_valid_d) begin
	w_addr <= w_addr + 1'b1;
      end
    end
  end // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n)
  // //

  // Generate write enable signal to swap between packet buffers //
  reg w_en_mem0;
  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      w_en_mem0 <= 1'b0;
    end
    else if (mpeg_clk_pos_edge) begin
      if (packet_done && running) begin
        w_en_mem0 <= ~w_en_mem0;
      end
      else if (~running) begin
        w_en_mem0 <= 1'b0;
      end
    end
  end
  // //

  // Switch between read data from packet buffer 0 and 1 //
  wire [MPEG_MEM_LENGTH - 1:0] r_data_mem0;
  wire [MPEG_MEM_LENGTH - 1:0] r_data_mem1;

  reg                          r_data_switch;
  
  always_ff @ (posedge sys_clk or negedge rst_n) begin //
    if (~rst_n) begin
      r_data_switch <= 1'b0;
    end
    else if (running_sys) begin
      r_data_switch <= r_en_mem0;
    end
  end
  assign r_data_32 = r_data_switch ? r_data_mem0 : r_data_mem1; // Read mem0 when mem1 is being written, and vice-versa
  // //
  
  // Create packet buffers //  
  packet_buffer
    #(
      .PACKET_LENGTH_BYTES(MPEG_PACKET_LENGTH_BYTES),
      .WRITE_DATA_WIDTH(MPEG_DATA_WIDTH),
      .READ_DATA_WIDTH(MPEG_MEM_LENGTH)
      ) 
  mpeg_packet_buffer_mem0
    (
     .rst_n(rst_n),
     
     .w_clk(~sys_clk),
     .w_en(w_en_mem0 & packet_started & mpeg_valid_d & mpeg_clk_pos_edge),
     .w_addr(w_addr),
     .w_data(mpeg_data_8_d),
     
     .r_clk(sys_clk),
     .r_en(r_en_mem0 & r_en),
     .r_addr(r_addr),
     .r_data(r_data_mem0)
     );
  
  packet_buffer 
    #(
      .PACKET_LENGTH_BYTES(MPEG_PACKET_LENGTH_BYTES),
      .WRITE_DATA_WIDTH(MPEG_DATA_WIDTH),
      .READ_DATA_WIDTH(MPEG_MEM_LENGTH)
      ) 
  mpeg_packet_buffer_mem1
    (
     .rst_n(rst_n),
     
     .w_clk(~sys_clk),
     .w_en(~w_en_mem0 & packet_started & mpeg_valid_d & mpeg_clk_pos_edge),
     .w_addr(w_addr),
     .w_data(mpeg_data_8_d),

     .r_clk(sys_clk),
     .r_en(~r_en_mem0 & r_en),
     .r_addr(r_addr),
     .r_data(r_data_mem1)
     );
  // //
    
  // running control //
  reg running;
  reg en_running;

  always_ff @ (posedge sys_clk or negedge rst_n) begin //
    if (~rst_n) begin
      running <= 1'b0;
    end
    else if (mpeg_clk_pos_edge) begin
      if (en_running) begin // && mpeg_sync) begin
        running <= 1'b1;
      end
      else if (~en_running) begin
        running <= 1'b0;
      end
    end
  end // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n)

  always_ff @ (posedge sys_clk or negedge rst_n) begin //
    if (~rst_n) begin
      en_running <= 1'b0;
    end
    else if (mpeg_clk_pos_edge) begin
      if (start) begin
        en_running <= 1'b1;
      end
      else if (stop) begin
        en_running <= 1'b0;
      end
    end
  end // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n)
  // //

  // Sync running into sys clk //
  reg running_sys_sync;
  reg running_sys;
  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      running_sys_sync <= 1'b0;
      running_sys <= 1'b0;
    end
    else begin
      running_sys_sync <= running;
      running_sys <= running_sys_sync;
    end
  end
  // // 
  
endmodule // mpeg_recorder
`default_nettype wire

