`default_nettype none
module mpeg_top_level 
  #(
    parameter MPEG_DATA_WIDTH = 8
    )
   (
    input wire				mpeg_clk_6MHz,
    input wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8,
    input wire				mpeg_sync,
    input wire				mpeg_valid,

    input wire				ref_clk_50MHz,
    input wire				rst_n,
    input wire				start_n,
    input wire				stop_n,
    

    output wire				mpeg_clk_6MHz_out,
    output wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8_out,
    output wire				mpeg_sync_out,
    output wire				mpeg_valid_out,

    output wire				lcd_cs_out,
    output wire				lcd_dcrs_out,
    output wire				lcd_sdi_out,
    output wire				lcd_sck_out,
    output wire				lcd_lcdrst_out
    );

   // PLL //
   wire sys_clk_100MHz;
   wire	pll_locked;
   pll pll0 
     (
      .refclk(ref_clk_50MHz),   //  refclk.clk
      .rst(~rst_n),	     //   reset.reset
      .outclk_0(sys_clk_100MHz), // outclk0.clk
      .locked(pll_locked)
      );
   // //
   
   // Gate rst_n behind pll lock //
   wire rst_n_gated;
   assign rst_n_gated = rst_n & pll_locked;
   // // 
   
   // assign mpeg_clk_6MHz_out = mpeg_clk_6MHz;
   // assign mpeg_data_8_out = mpeg_data_8;
   // assign mpeg_sync_out = mpeg_sync;
   // assign mpeg_valid_out = mpeg_valid;

   // Synchronise start and stop //
   reg start_tmp;
   reg stop_tmp;
   reg start_sync;
   reg stop_sync;
   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n_gated) begin
      if (~rst_n_gated) begin
	 start_tmp <= 1'b1;
	 stop_tmp <= 1'b1;
	 start_sync <= 1'b1;
	 stop_sync <= 1'b1;
      end
      else begin
	 start_tmp <= start_n;
	 stop_tmp <= stop_n;

	 start_sync <= start_tmp;
	 stop_sync <= stop_tmp;
      end
   end
   // //

   // mpeg recorder //
   mpeg_recorder
     #(
       .MPEG_DATA_WIDTH(MPEG_DATA_WIDTH)
       )
   mpeg_mpeg_recorder_0
     (
      .rst_n(rst_n_gated),
      .mpeg_clk_6MHz(mpeg_clk_6MHz),
      .mpeg_data_8(mpeg_data_8),
      .mpeg_sync(mpeg_sync),
      .mpeg_valid(mpeg_valid),
      .sys_clk_40MHz(),
      .start(~start_sync),
      .stop(~stop_sync),
      .mpeg_clk_6MHz_out(mpeg_clk_6MHz_out),
      .mpeg_data_8_out(mpeg_data_8_out),
      .mpeg_sync_out(mpeg_sync_out),
      .mpeg_valid_out(mpeg_valid_out)
      );
   // //

   // LCD //
   msp2807_controller lcd0
     (
      .rst_n(rst_n_gated),
      .sys_clk_100MHz(sys_clk_100MHz),
      .pixel_data(16'hAFF5),
      .pixel_available(1'b1),
      .pixel_done(),
      .o_cs(lcd_cs_out),
      .o_dcrs(lcd_dcrs_out),
      .o_sdi(lcd_sdi_out),
      .o_sck(lcd_sck_out),
      .o_lcdrst(lcd_lcdrst_out),
      .rst_coord(1'b0),
      .x(),
      .y(),
      .bufferIndex()
      );
   
   
   // //
   
endmodule // mpeg_top_level
`default_nettype wire
  
