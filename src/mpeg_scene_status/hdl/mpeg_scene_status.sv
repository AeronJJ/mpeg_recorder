`default_nettype none
module mpeg_scene_status
  (
   input wire         rst_n,
   input wire         clk,
   input wire         en,

   input wire [3:0]   mode,
   input wire         recording,
  
   input wire [8:0]   x,             // Current pixel position
   input wire [7:0]   y,
   output wire        pixel_set,
   output wire [15:0] pixel_colour // 16 bit colour of current pixel.
   );
  
  import msp2807_colours::*;
  
  // Pixel Multiplexer //
  always_comb begin
    if (circle_pixel_set) begin
      pixel_colour = circle_pixel_colour;
    end
    else if (recording_text_pixel_set) begin
      pixel_colour = recording_text_pixel_colour;
    end
    else if (idle_text_pixel_set) begin
      pixel_colour = idle_text_pixel_colour;
    end
    else begin
      pixel_colour = 16'b0;
    end
  end // always_comb

  assign pixel_set = circle_pixel_set || recording_text_pixel_set || idle_text_pixel_set;
  // //

  // Recording Indicator //
  // Timer to generate flashing
  localparam COUNTER_RESET_VAL = 50000000; // 50 million = 1 Hz flash period
  reg [31:0] flash_counter;
  reg        flash;
  always_ff @ (posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      flash_counter <= '0;
      flash <= 1'b0;
    end
    else if (recording) begin
      if (flash_counter == '0) begin
        flash_counter <= COUNTER_RESET_VAL;
        flash <= ~flash;
      end
      else begin
        flash_counter <= flash_counter - 1'b1;
      end
    end
  end

  // Generate circle colour
  reg [15:0] circle_colour;
  always_comb begin
    case (mode)
      4'b0001: begin
        // Idle
        circle_colour = MSP_WHITE;
      end

      4'b0010: begin
        // Passthrough
        circle_colour = MSP_GREEN;
      end

      4'b0100: begin
        // Record    
        if (recording) begin
          if (flash) begin
            circle_colour = MSP_RED;
          end
          else begin
            circle_colour = MSP_WHITE;
          end
        end
        else begin
          circle_colour = MSP_YELLOW;
        end
      end

      4'b1000: begin
        // Playback
        circle_colour = MSP_BLUE;
      end

      default: begin
        // Else
        circle_colour = MSP_WHITE;
      end
    endcase
  end // always_comb

  wire circle_pixel_set;
  wire [15:0] circle_pixel_colour;
  mpeg_scene_primitive_circle status_led
    (
     .en(en),
     .x_pos(265),
     .y_pos(35),
     .x_check(x),
     .y_check(y),
     .radius(20),
     .circle_colour(circle_colour),
     .in_circle(circle_pixel_set), // Pixel set
     .pixel_colour(circle_pixel_colour)
     );
  // //

  // Recording text //
  wire recording_text_pixel_set;
  wire [15:0] recording_text_pixel_colour;
    
  mpeg_scene_primitive_text
    #(
      .X_POS(220),
      .Y_POS(65),
      .SIZE(1),
      .LENGTH(9),
      .TEXT('{FONT_R, FONT_e, FONT_c, FONT_o, FONT_r, FONT_d, FONT_i, FONT_n, FONT_g})
      )
  recording_text_inst
    (
     .en(mode[2] && recording && en),
     .x(x),
     .y(y),
     .pixel_colour(recording_text_pixel_colour),
     .pixel_set(recording_text_pixel_set)
     );
  // //

  // Idle text //
  wire idle_text_pixel_set;
  wire [15:0] idle_text_pixel_colour;
    
  mpeg_scene_primitive_text
    #(
      .X_POS(245),
      .Y_POS(65),
      .SIZE(1),
      .LENGTH(4),
      .TEXT('{FONT_I, FONT_d, FONT_l, FONT_e})
      )
  idle_text_inst
    (
     .en(mode[2] && ~recording && en),
     .x(x),
     .y(y),
     .pixel_colour(idle_text_pixel_colour),
     .pixel_set(idle_text_pixel_set)
     );
  
  // //
    
  
endmodule // mpeg_scene_status
`default_nettype wire
  
