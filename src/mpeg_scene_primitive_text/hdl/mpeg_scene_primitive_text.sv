`default_nettype none
module mpeg_scene_primitive_text 
  import FONT_DEFINITION::*, msp2807_colours::*;
  #(
    parameter			     X_POS = 0, 
    parameter			     Y_POS = 0, 
    parameter			     SIZE = 1, 
    parameter			     COLOUR = MSP_BLACK, 
    parameter			     LENGTH = 4, 
    parameter logic [0:FONT_WIDTH-1] TEXT [0:LENGTH-1][0:FONT_HEIGHT-1] = '{FONT_T, FONT_e, FONT_s, FONT_t}
    )
   (
    input wire	       en,
    input wire [8:0]   x,
    input wire [7:0]   y,
    output wire [15:0] pixel_colour,
    output wire	       pixel_set
    );

   assign pixel_colour = pixel_set ? COLOUR : MSP_BLACK;//16'h0000;//16'hFFFF;

   reg [LENGTH-1:0] internal_active;
   assign pixel_set = en && (|internal_active);

   genvar i;
   generate
      for (i=0; i < LENGTH; i = i+1) begin : letter_generator
	 mpeg_scene_primitive_letter 
	   #(
	     .X_POS(X_POS + (FONT_WIDTH<<(SIZE-1))*i),
	     .Y_POS(Y_POS), 
	     .SIZE(SIZE), 
	     .LETTER(TEXT[i])) 
	 mpeg_scene_primitive_letter0
	   (
	    .x(x),
	    .y(y),
	    .pixel_set(internal_active[i])
	    );
      end
   endgenerate
endmodule // mpeg_scene_primitive_text
`default_nettype wire
  
