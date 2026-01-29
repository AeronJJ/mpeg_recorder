`default_nettype none
module mpeg_scene_mode_selection 
  #(
    parameter NUM_PRIMITIVES = 3
    )
   (
    input wire	       rst_n,
    input wire	       clk, 
    
    input wire [8:0]   x,	      // Current pixel position
    input wire [7:0]   y,
    output wire [15:0] current_pixel, // 16 bit colour of current pixel.

    input wire [8:0]   touch_x,
    input wire [7:0]   touch_y,
    input wire	       touch_detected,
    output reg [3:0]  mode
    );

   import msp2807_colours::*;

   wire [NUM_PRIMITIVES - 1:0] pixel_set;
   wire [NUM_PRIMITIVES - 1:0][15:0] pixel_colours;
   reg [15:0]			     pixel_colour;

   wire				     passthrough_touched;
   wire				     record_touched;
   wire				     playback_touched;

   always_ff @ (posedge clk or negedge rst_n) begin // TODO: Does this need to be registered logic?
      if (~rst_n) begin
	 mode <= 4'b0;
      end
      else begin
	 mode[0] <= ~(passthrough_touched | record_touched | playback_touched);
	 mode[1] <= passthrough_touched;
	 mode[2] <= record_touched;
	 mode[3] <= playback_touched;
      end
   end
   

   always_comb begin
      pixel_colour = 16'b0;
      for (int i = 0; i < NUM_PRIMITIVES; i = i + 1) begin
	 pixel_colour |= pixel_colours[i];
      end
   end
   
   assign current_pixel = pixel_set ? pixel_colour : MSP_WHITE;
   
   mpeg_scene_primitive_rectangle
     #(
       .X_POS(10),
       .Y_POS(10),
       .X_LENGTH(200),
       .Y_LENGTH(60),
       .COLOUR_RGB565(MSP_WHITE),
       .EN_TEXT(1'b1),
       .TEXT_LENGTH(11),
       .TEXT('{FONT_P, FONT_a, FONT_s, FONT_s, FONT_t, FONT_h, FONT_r, FONT_o, FONT_u, FONT_g, FONT_h}),
       .EN_TOUCH(1'b1)
       )
   passthrough_sq 
     (
      .x(x),
      .y(y),
      .pixel_set(pixel_set[0]),
      .pixel_colour(pixel_colours[0]),
      .touch_x(touch_x),
      .touch_y(touch_y),
      .touched(passthrough_touched)
      );
   
   mpeg_scene_primitive_rectangle
     #(
       .X_POS(10),
       .Y_POS(80),
       .X_LENGTH(200),
       .Y_LENGTH(60),
       .COLOUR_RGB565(MSP_WHITE),
       .EN_TEXT(1'b1),
       .TEXT_LENGTH(6),
       .TEXT('{FONT_R, FONT_e, FONT_c, FONT_o, FONT_r, FONT_d}),
       .EN_TOUCH(1'b1)
       )
   record_sq 
     (
      .x(x),
      .y(y),
      .pixel_set(pixel_set[1]),
      .pixel_colour(pixel_colours[1]),
      .touch_x(touch_x),
      .touch_y(touch_y),
      .touched(record_touched)
      );

   mpeg_scene_primitive_rectangle
     #(
       .X_POS(10),
       .Y_POS(150),
       .X_LENGTH(200),
       .Y_LENGTH(60),
       .COLOUR_RGB565(MSP_WHITE),
       .EN_TEXT(1'b1),
       .TEXT_LENGTH(8),
       .TEXT('{FONT_P, FONT_l, FONT_a, FONT_y, FONT_b, FONT_a, FONT_c, FONT_k}),
       .EN_TOUCH(1'b1)
       )
   playback_sq 
     (
      .x(x),
      .y(y),
      .pixel_set(pixel_set[2]),
      .pixel_colour(pixel_colours[2]),
      .touch_x(touch_x),
      .touch_y(touch_y),
      .touched(playback_touched)
      );

   
endmodule // mpeg_scene_mode_selection
`default_nettype wire
  
