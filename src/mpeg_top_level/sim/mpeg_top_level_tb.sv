`timescale 1ns/100ps
module mpeg_top_level_tb;

   localparam CLK_FREQ = 100E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;
   **PARAM_LIST**
   
   **NET_LIST**

   **DUT_INST**

   always #(CLK_HALF_PERIOD_NS) begin
      clk_i = ~clk_i;
   end

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      
      
      $finish;
   end
   
endmodule // mpeg_top_level_tb
