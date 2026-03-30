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
  assign idle_irq = mode[1] || mode[0];
  assign record_irq = mode[2];
  assign playback_irq = mode[3];
    
endmodule // mpeg_recorder_mode_select_interface
`default_nettype wire
  
