`timescale 1ns/100ps
module byte_unpacker_tb;

   localparam CLK_FREQ = 6E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   localparam NUM_WRITE_BITS = 32;
   localparam NUM_READ_BITS = 8;
      
   reg rst_n_i;
   reg [NUM_WRITE_BITS - 1:0] w_data_i;
   reg			      r_clk_i;
   wire [NUM_READ_BITS - 1:0] r_data_o;
   reg			      en_i;
   reg			      sync_i;
   wire			      mpeg_sync_o;
	

   byte_unpacker dut_byte_unpacker (
	.rst_n(rst_n_i),
	.w_data(w_data_i),
	.r_clk(r_clk_i),
	.r_data(r_data_o),
	.en(en_i),
	.sync(sync_i),
	.mpeg_sync(mpeg_sync_o)
	);

   always #(CLK_HALF_PERIOD_NS) begin
      r_clk_i = ~r_clk_i;
   end

   always_ff @ (posedge r_clk_i) begin
      w_data_i <= w_data_i + NUM_WRITE_BITS'(1);
   end

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      rst_n_i = 1;
      w_data_i = '0;
      r_clk_i = 0;
      en_i = 0;
      sync_i = 0;

      @ (posedge r_clk_i);
      @ (posedge r_clk_i);

      rst_n_i = 0;

      @ (posedge r_clk_i);
      @ (posedge r_clk_i);

      rst_n_i = 1;

      @ (posedge r_clk_i);
      @ (posedge r_clk_i);

      en_i = 1;
      sync_i = 1;

      @ (posedge r_clk_i);
      @ (posedge r_clk_i);
      @ (posedge r_clk_i);
      @ (posedge r_clk_i);

      sync_i = 0;
      
      #(1000*CLK_HALF_PERIOD_NS);
      
      $finish;
   end
   
endmodule // byte_unpacker_tb
