`timescale 1ns/100ps
module mpeg_recorder_tb;

   localparam CLK_FREQ = 40E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   localparam MPEG_CLK_FREQ = 6E6;
   localparam MPEG_CLK_HALF_PERIOD_NS = 5E8/MPEG_CLK_FREQ; 

   localparam MPEG_DATA_WIDTH = 8;
   localparam MPEG_MEM_LENGTH = 32;
      
   reg	      rst_n_i;
   reg	      mpeg_clk_6MHz_i;
   reg [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_i;
   reg			       mpeg_sync_i;
   reg			       mpeg_valid_i;
   reg			       sys_clk_40MHz_i;
   reg			       start_i;
   reg			       stop_i;

   wire			       mpeg_clk_6MHz_out_o;
   wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8_out_o;
   wire [MPEG_MEM_LENGTH - 1:0]	r_data_o;
   wire				mpeg_sync_out_o;
   wire				mpeg_valid_out_o;
   
   

   mpeg_recorder dut_mpeg_recorder
     (
      .rst_n(rst_n_i),
      .mpeg_clk_6MHz(mpeg_clk_6MHz_i),
      .mpeg_data_8(mpeg_data_8_i),
      .mpeg_sync(mpeg_sync_i),
      .mpeg_valid(mpeg_valid_i),
      .sys_clk_40MHz(sys_clk_40MHz_i),
      .start(start_i),
      .stop(stop_i),
      .mpeg_clk_6MHz_out(mpeg_clk_6MHz_out_o),
      .mpeg_data_8_out(mpeg_data_8_out_o),
      .r_data(r_data_o),
      .mpeg_sync_out(mpeg_sync_out_o),
      .mpeg_valid_out(mpeg_valid_out_o)
      );

   always begin
      while (~mpeg_sync_i) begin
	 #1;
      end
      // @ (posedge mpeg_sync_i);
      mpeg_clk_6MHz_i = 1'b1;
      fork
	 forever begin
	    #(MPEG_CLK_HALF_PERIOD_NS) mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
	 end
	 @ (posedge mpeg_sync_i);
      join_any
      disable fork;
   end

   always #(CLK_HALF_PERIOD_NS) begin
      sys_clk_40MHz_i = ~sys_clk_40MHz_i;
   end

   // always #(MPEG_CLK_HALF_PERIOD_NS) begin
   //    mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
   // end
   
   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      rst_n_i = 1'b0;
      mpeg_clk_6MHz_i = 1'b0;
      sys_clk_40MHz_i = 1'b0;
      
      start_i = 1'b0;

      #(6 * MPEG_CLK_HALF_PERIOD_NS);

      rst_n_i = 1'b1;

      #(6 * MPEG_CLK_HALF_PERIOD_NS);
      
      @ (posedge mpeg_clk_6MHz_i);
      
      start_i = 1'b1;
      #(6 * MPEG_CLK_HALF_PERIOD_NS);
      
      @ (posedge vcd_done);
      $finish;
   end // initial begin

   /* INSERT */
   
endmodule // mpeg_recorder_tb
