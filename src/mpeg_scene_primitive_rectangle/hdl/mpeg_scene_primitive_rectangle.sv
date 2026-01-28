`default_nettype none
import msp2807_colours::*, FONT_DEFINITION::*;
module mpeg_scene_primitive_rectangle 
  #(
    parameter			     X_POS = 0,
    parameter			     Y_POS = 0,
    parameter			     X_LENGTH = 26,
    parameter			     Y_LENGTH = 26,
    parameter			     BORDER_WIDTH = 3,
    parameter			     COLOUR_RGB565 = MSP_WHITE,
    parameter			     EN_TEXT = 1'b0,
    parameter			     TEXT_COLOUR = MSP_BLACK,
    parameter			     TEXT_LENGTH = 4,
    parameter			     TEXT_LEFT_JUSTIFICATION_PIXELS = 5,
    parameter			     TEXT_SIZE = 2,
    parameter logic [0:FONT_WIDTH-1] TEXT [0:TEXT_LENGTH-1][0:FONT_HEIGHT-1] = '{FONT_T, FONT_e, FONT_s, FONT_t}
    )
   (
    input wire [8:0]   x, 
    input wire [7:0]   y,
    output wire	       pixel_set, 
    output wire [15:0] pixel_colour
    );

   generate
      if (EN_TEXT) begin
	 wire [15:0] text_colour;
	 wire text_pixel_set;
	 mpeg_scene_primitive_text
	   #(
	     .X_POS(X_POS + BORDER_WIDTH + TEXT_LEFT_JUSTIFICATION_PIXELS),
	     .Y_POS(Y_POS + (Y_LENGTH / 2) - (FONT_HEIGHT*(1<<(TEXT_SIZE-1))) / 2),
	     .SIZE(TEXT_SIZE),
	     .COLOUR(TEXT_COLOUR),
	     .LENGTH(TEXT_LENGTH),
	     .TEXT(TEXT)
	     )
	 mpeg_scene_primitive_text0
	   (
	    .en(1'b1),
	    .x(x),
	    .y(y),
	    .pixel_colour(text_colour),
	    .pixel_set(text_pixel_set)
	    );

	 // If isX > x + length && isY > y + length then isSet = true
	 assign pixel_set = text_pixel_set || ((x > X_POS) && (x < (X_POS + X_LENGTH)) && (y > Y_POS) && (y < (Y_POS + Y_LENGTH)));
	 assign pixel_colour = text_pixel_set ? text_colour : (x < (X_POS + BORDER_WIDTH)) || (x > (X_POS + X_LENGTH - BORDER_WIDTH)) || (y < (Y_POS + BORDER_WIDTH)) || (y > (Y_POS + Y_LENGTH - BORDER_WIDTH)) ? 16'b0 : COLOUR_RGB565;

      end // if (EN_TEXT)
      else begin	 
	 // If isX > x + length && isY > y + length then isSet = true
	 assign pixel_set = (x > X_POS) && (x < (X_POS + X_LENGTH)) && (y > Y_POS) && (y < (Y_POS + Y_LENGTH));
	 assign pixel_colour = (x < (X_POS + BORDER_WIDTH)) || (x > (X_POS + X_LENGTH - BORDER_WIDTH)) || (y < (Y_POS + BORDER_WIDTH)) || (y > (Y_POS + Y_LENGTH - BORDER_WIDTH)) ? 16'b0 : COLOUR_RGB565;
      end // else: !if(EN_TEXT)
   endgenerate
   
endmodule // mpeg_scene_primitive_rectangle
`default_nettype wire
  
