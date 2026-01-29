`default_nettype none
module mpeg_scene_primitive_touch_rectangle 
  #(
    parameter X_POS = 0,
    parameter Y_POS = 0,
    parameter X_LENGTH = 0,
    parameter Y_LENGTH = 0
    )
   (
    input wire	     en,
    input wire [8:0] touch_x,
    input wire [7:0] touch_y,
    output wire	     touched
    );

   assign touched = en ? (touch_x > X_POS) && (touch_x < (X_POS + X_LENGTH)) && (touch_y > Y_POS) && (touch_y < (Y_POS + Y_LENGTH)) : 1'b0;
   
endmodule // mpeg_scene_primitive_touch_rectangle
`default_nettype wire
  
