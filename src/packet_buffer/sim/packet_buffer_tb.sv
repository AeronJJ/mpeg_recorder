`timescale 1ns/100ps
module packet_buffer_tb;

   localparam CLK_FREQ = 100E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;
   
   
   reg	      rst_n_i;
   reg	      w_clk_i;
   reg	      w_en_i;
   reg [ADDR_WIDTH - 1:0] w_addr_i;
   reg [MEM_WIDTH - 1:0]  w_data_i;
   reg			  r_clk_i;
   reg			  r_en_i;
   reg [ADDR_WDTH - 1:0]  r_addr_i;
   wire [MEM_WIDTH - 1:0] r_data_o;
	

   packet_buffer dut_packet_buffer (
	.rst_n(rst_n_i),
	.w_clk(w_clk_i),
	.w_en(w_en_i),
	.w_addr(w_addr_i),
	.w_data(w_data_i),
	.r_clk(r_clk_i),
	.r_en(r_en_i),
	.r_addr(r_addr_i),
	.r_data(r_data_o)
	);

   always #(CLK_HALF_PERIOD_NS) begin
      clk_i = ~clk_i;
   end

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      
      
      $finish;
   end
   
endmodule // packet_buffer_tb
