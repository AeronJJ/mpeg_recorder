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

   // Synchronise start and stop //
   reg start_tmp;
   reg stop_tmp;
   reg start_sync;
   reg stop_sync;
   always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n) begin
      if (~rst_n) begin
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
      .start(~start_sync),
      .stop(~stop_sync),
      .mpeg_clk_6MHz_out(mpeg_clk_6MHz_out),
      .mpeg_data_8_out(mpeg_data_8_out),
      .mpeg_sync_out(mpeg_sync_out),
      .mpeg_valid_out(mpeg_valid_out)
      );
   
   
endmodule // mpeg_top_level
`default_nettype wire
  
