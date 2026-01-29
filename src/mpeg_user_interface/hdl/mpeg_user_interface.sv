`default_nettype none
module mpeg_user_interface 
  #(
    parameter NULL = 0
    )
   (
    input wire	      rst_n,
    input wire	      sys_clk_100MHz,
    input wire	      sys_clk_1MHz,

    output wire [3:0] mode, // Onehot (playback, record, passthrough, idle)

    output wire	      lcd_cs_out,
    output wire	      lcd_dcrs_out,
    output wire	      lcd_sdi_out,
    output wire	      lcd_sck_out,
    output wire	      lcd_lcdrst_out,

    input wire	      touch_sdo_in,
    input wire	      touch_irq_in,
    output wire	      touch_cs_out,
    output wire	      touch_sdi_out,
    output wire	      touch_sck_out
    );

   // assign mode = 4'b0001;
   
   // Touch //
   wire [8:0] touch_x;
   wire [7:0] touch_y;
   wire	      touch_detected;
   
   msp2807_touch_controller msp2807_touch_controller0
     (
      .rst_n(rst_n),
      .sys_clk_1MHz(sys_clk_1MHz),
      .touch_sdo_in(touch_sdo_in),
      .touch_irq_in(touch_irq_in),
      .touch_cs_out(touch_cs_out),
      .touch_sdi_out(touch_sdi_out),
      .touch_sck_out(touch_sck_out),
      .touch_x(touch_x),
      .touch_y(touch_y),
      .touch_detected(touch_detected)
      );
   
   // //
   
   
   // LCD //
   wire [8:0] x;
   wire [7:0] y;
   wire [15:0] pixel;
   
   msp2807_controller lcd0
     (
      .rst_n(rst_n),
      .sys_clk_100MHz(sys_clk_100MHz),
      .pixel_data(pixel),
      .pixel_available(1'b1),
      .pixel_done(),
      .o_cs(lcd_cs_out),
      .o_dcrs(lcd_dcrs_out),
      .o_sdi(lcd_sdi_out),
      .o_sck(lcd_sck_out),
      .o_lcdrst(lcd_lcdrst_out),
      .rst_coord(1'b0),
      .x(x),
      .y(y),
      .bufferIndex()
      );
   // //

   // Mode Selection Scene //
   mpeg_scene_mode_selection mpeg_scene_mode_selection0
     (
      .rst_n(rst_n),
      .clk(sys_clk_1MHz),
      .x(x),
      .y(y),
      .current_pixel(pixel),
      .touch_x(touch_x),
      .touch_y(touch_y),
      .touch_detected(touch_detected),
      .mode(mode)
      );
   // //
   
endmodule // mpeg_user_interface
`default_nettype wire
  
