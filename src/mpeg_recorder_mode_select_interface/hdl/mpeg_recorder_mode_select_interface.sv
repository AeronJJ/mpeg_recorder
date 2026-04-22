`default_nettype none
module mpeg_recorder_mode_select_interface 
  (
   input wire       rst,
   input wire       clk,
   
   input wire [3:0] mode, // Onehot (playback, record, passthrough, idle)

   output wire      idle_irq,
   output wire      record_irq,
   output wire      playback_irq      
   );

  // Pass mode directly to output, not ideal, should probably edge detect and extend pulse to ensure its registered. But irqs should be edge detect based anyway
  wire idle_irq_in = mode[1] || mode[0];
  wire record_irq_in = mode[2];
  wire playback_irq_in = mode[3];

  reg  idle_irq_in_d;
  reg  record_irq_in_d;
  reg  playback_irq_in_d;

  int  counter;

  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      counter <= 32'd100;
      idle_irq_in_d <= 1'b0;
      record_irq_in_d <= 1'b0;
      playback_irq_in_d <= 1'b0;
    end
    else if (counter == '0) begin
      counter <= 32'd100;
      idle_irq_in_d <= idle_irq_in;
      record_irq_in_d <= record_irq_in;
      playback_irq_in_d <= playback_irq_in;
    end
    else begin
      counter <= counter - 1'b1;
    end
  end // always_ff @ (posedge clk or posedge rst)

  assign idle_irq = (idle_irq_in_d ^ idle_irq_in) & idle_irq_in;
  assign record_irq = (record_irq_in_d ^ record_irq_in) & record_irq_in;
  assign playback_irq = (playback_irq_in_d ^ playback_irq_in) & playback_irq_in;
    
endmodule // mpeg_recorder_mode_select_interface
`default_nettype wire
  
