`timescale 1ns/100ps
module mpeg_read_addr_gen_tb;

   localparam CLK_FREQ = 6E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   localparam MPEG_ADDR_WIDTH = 8;
   localparam MPEG_PACKET_LENGTH = 188;
   
   reg	      rst_n_i;
   reg	      r_clk_i;
   reg	      en_i;
   reg	      start_i;
   wire [MPEG_ADDR_WIDTH - 1:0]	r_addr_o;
   wire				r_end_o;
	
   
   mpeg_read_addr_gen
     #(.MPEG_ADDR_WIDTH(MPEG_ADDR_WIDTH), .MPEG_PACKET_LENGTH(MPEG_PACKET_LENGTH))
   dut_mpeg_read_addr_gen (
	.rst_n(rst_n_i),
	.r_clk(r_clk_i),
	.en(en_i),
	.start(start_i),
	.r_addr(r_addr_o),
	.r_end(r_end_o)
	);

   always #(CLK_HALF_PERIOD_NS) begin
      r_clk_i = ~r_clk_i;
   end

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      en_i = 0;
      start_i = 0;
      r_clk_i = 0;
      rst_n_i = 0;
      #(2*CLK_HALF_PERIOD_NS);
      rst_n_i = 1;
      #(2*CLK_HALF_PERIOD_NS);
      
      en_i = 1;
      
      #(4*CLK_HALF_PERIOD_NS);

      start_i = 1;
      
      // #(2*CLK_HALF_PERIOD_NS);
      
      // start_i = 0;
      
      @(posedge r_end_o);

      @(posedge r_end_o);

      #(2*CLK_HALF_PERIOD_NS);
      
      $finish;
   end
   
endmodule // mpeg_read_addr_gen_tb
