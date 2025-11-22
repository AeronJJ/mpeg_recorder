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

    output wire				mpeg_clk_6MHz_out,
    output wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8_out,
    output wire				mpeg_sync_out,
    output wire				mpeg_valid_out
    );

   assign mpeg_clk_6MHz_out = mpeg_clk_6MHz;
   assign mpeg_data_8_out = mpeg_data_8;
   assign mpeg_sync_out = mpeg_sync;
   assign mpeg_valid_out = mpeg_valid;

   // always_ff @ (posedge mpeg_clk_6MHz) begin
   //    if (mpeg_clk_6MHz) begin
   // 	 mpeg_data_8_out <= mpeg_data_8;
   // 	 mpeg_sync_out <= mpeg_sync;
   // 	 mpeg_valid_out <= mpeg_valid;
   //    end
   // end
   
endmodule // mpeg_top_level
`default_nettype wire
  
