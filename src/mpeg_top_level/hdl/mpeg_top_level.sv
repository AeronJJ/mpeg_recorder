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

    input wire				rst_n,
    input wire				start_n,
    input wire				stop_n,
    

    output wire				mpeg_clk_6MHz_out,
    output wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8_out,
    output wire				mpeg_sync_out,
    output wire				mpeg_valid_out
    );

   // assign mpeg_clk_6MHz_out = mpeg_clk_6MHz;
   // assign mpeg_data_8_out = mpeg_data_8;
   // assign mpeg_sync_out = mpeg_sync;
   // assign mpeg_valid_out = mpeg_valid;

   mpeg_recorder
     #(
       .MPEG_DATA_WIDTH(MPEG_DATA_WIDTH)
       )
   mpeg_mpeg_recorder_0
     (
      .rst_n(rst_n),
      .mpeg_clk_6MHz(mpeg_clk_6MHz),
      .mpeg_data_8(mpeg_data_8),
      .mpeg_sync(mpeg_sync),
      .mpeg_valid(mpeg_valid),
      .sys_clk_40MHz(),
      .start(start_n),
      .stop(stop_n),
      .r_data(mpeg_data_8_out)
      );
   
   
endmodule // mpeg_top_level
`default_nettype wire
  
