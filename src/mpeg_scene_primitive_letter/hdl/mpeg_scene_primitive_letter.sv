`default_nettype none
module mpeg_scene_primitive_letter
  import FONT_DEFINITION::*;
  #(
    parameter X_POS = 0,
    parameter Y_POS = 0,
    parameter SIZE = 1,
    parameter logic [0:FONT_WIDTH-1] LETTER [0:FONT_HEIGHT-1] = FONT_A
    )
   (
    input wire [8:0] x,
    input wire [7:0] y,
    output wire	     pixel_set
    );

assign pixel_set = ((x - X_POS) >= 0 && 
                    (y - Y_POS) >= 0 && 
                    (x - X_POS) < FONT_WIDTH*(1<<(SIZE-1)) && 
                    (y - Y_POS) < FONT_HEIGHT*(1<<(SIZE-1)) && 
                    LETTER[(y - Y_POS)>>(SIZE-1)][(x - X_POS)>>(SIZE-1)]) ? 1'b1 : 1'b0;
   
endmodule // mpeg_scene_primitive_letter
`default_nettype wire
  
