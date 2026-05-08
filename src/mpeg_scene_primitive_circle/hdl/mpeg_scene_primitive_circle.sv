`default_nettype none
module mpeg_scene_primitive_circle
  #(
    parameter SCREEN_WIDTH = 320,
    parameter SCREEN_HEIGHT = 240,
    parameter X_WIDTH = $clog2(SCREEN_WIDTH),
    parameter Y_WIDTH = $clog2(SCREEN_HEIGHT)
    )
  (
   input wire                 en,
   input wire [X_WIDTH - 1:0] x_pos, // Centre of circle
   input wire [Y_WIDTH - 1:0] y_pos, // Centre of circle
   input wire [X_WIDTH - 1:0] x_check,
   input wire [Y_WIDTH - 1:0] y_check,
   input wire [Y_WIDTH - 1:0] radius,
   input wire [15:0]          circle_colour,
   output wire                in_circle,
   output wire [15:0]         pixel_colour
   );

  localparam DX_WIDTH = X_WIDTH + 1; // Extra bit for sign
  localparam DY_WIDTH = Y_WIDTH + 1;
  localparam DIST_WIDTH = (2*DX_WIDTH > 2*DY_WIDTH ? 2*DX_WIDTH : 2*DY_WIDTH) + 1;
  
  wire signed [DX_WIDTH:0] dx;
  wire signed [DY_WIDTH:0] dy;
  
  assign dx = $signed({1'b0, x_check}) - $signed({1'b0, x_pos});
  assign dy = $signed({1'b0, y_check}) - $signed({1'b0, y_pos});

  wire [DIST_WIDTH - 1:0] dist_sq;
  wire [DIST_WIDTH - 1:0] radius_sq;
  
  assign dist_sq = dx*dx + dy*dy;
  assign radius_sq = radius*radius;

  assign in_circle = en && (dist_sq <= radius_sq);
  
  assign pixel_colour = in_circle ? circle_colour : 16'h0000;

endmodule // mpeg_scene_primitive_circle
`default_nettype wire
