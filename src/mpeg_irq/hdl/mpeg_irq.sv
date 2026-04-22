`default_nettype none
module mpeg_irq
  (
   input wire clk,
   input wire rst_n,
   input wire en_interrupt,

   output reg irq,
   input wire irq_reset
   );

  // Detect irq_reset edge //
  wire irq_reset_edge = (irq_reset_d ^ irq_reset);
  reg  irq_reset_d;
  always_ff @ (posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      irq_reset_d <= 1'b0;
    end
    else begin
      irq_reset_d <= irq_reset;
    end
  end
  // //

  // Control irq //
  always_ff @ (posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      irq <= 1'b0;
    end
    else if (irq_reset_edge) begin
      irq <= 1'b0;
    end
    else if (en_interrupt) begin
      irq <= 1'b1;
    end
  end // always_ff @ (posedge clk or negedge rst_n)
  // //
  
endmodule // mpeg_irq
`default_nettype wire

