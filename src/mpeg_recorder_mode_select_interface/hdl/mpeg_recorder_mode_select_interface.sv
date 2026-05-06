`default_nettype none
module mpeg_recorder_mode_select_interface 
  (
   input wire       rst,
   input wire       clk,
   
   input wire [3:0] mode, // Onehot (playback, record, passthrough, idle)

   output wire      idle_irq,
   output wire      record_irq,
   output wire      playback_irq,

   input wire       idle_irq_received,
   input wire       record_irq_received,
   input wire       playback_irq_received
   );

  wire idle_irq_in = mode[1] || mode[0];
  wire record_irq_in = mode[2];
  wire playback_irq_in = mode[3];

  reg  idle_irq_in_d;
  reg  record_irq_in_d;
  reg  playback_irq_in_d;

  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      idle_irq_in_d <= 1'b0;
      record_irq_in_d <= 1'b0;
      playback_irq_in_d <= 1'b0;
    end
    else begin
      idle_irq_in_d <= idle_irq_in;
      record_irq_in_d <= record_irq_in;
      playback_irq_in_d <= playback_irq_in;      
    end
  end // always_ff @ (posedge clk or posedge rst)

  // Pos edge detect for enable
  wire en_idle_irq = (idle_irq_in ^ idle_irq_in_d) & idle_irq_in;
  wire en_record_irq = (record_irq_in ^ record_irq_in_d) & record_irq_in;
  wire en_playback_irq = (playback_irq_in ^ playback_irq_in_d) & playback_irq_in;

  // Instantiate IRQs //
  mpeg_irq mpeg_irq_idle_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_idle_irq),
     .irq(idle_irq),
     .irq_reset(idle_irq_received)
     );
  
  mpeg_irq mpeg_irq_record_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_record_irq),
     .irq(record_irq),
     .irq_reset(record_irq_received)
     );

  mpeg_irq mpeg_irq_playback_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_playback_irq),
     .irq(playback_irq),
     .irq_reset(playback_irq_received)
     );
  // //

endmodule // mpeg_recorder_mode_select_interface
`default_nettype wire
  
