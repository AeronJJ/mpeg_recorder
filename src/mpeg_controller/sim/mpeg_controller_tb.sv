`timescale 1ns/100ps
module mpeg_controller_tb;

   localparam CLK_FREQ = 6E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;
   
   localparam PACKET_LENGTH = 188;
   localparam ADDR_WIDTH = $clog2(PACKET_LENGTH);
   
	      
   reg rst_n_i;
   reg mpeg_clk_6MHz_i;
   reg packet_done_pulse_i;
   wire	r_en_o;
   wire [ADDR_WIDTH - 1:0] r_addr_o;
   wire			   mpeg_sync_out_o;
   wire			   mpeg_valid_out_o;
	

   mpeg_controller 
     #(.PACKET_LENGTH(PACKET_LENGTH))
   dut_mpeg_controller 
     (
      .rst_n(rst_n_i),
      .mpeg_clk_6MHz(mpeg_clk_6MHz_i),
      .packet_done_pulse(packet_done_pulse_i),
      .r_en(r_en_o),
      .r_addr(r_addr_o),
      .mpeg_sync_out(mpeg_sync_out_o),
      .mpeg_valid_out(mpeg_valid_out_o)
      );
   
   always #(CLK_HALF_PERIOD_NS) begin
      mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
   end

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      mpeg_clk_6MHz_i = 0;
      rst_n_i = 0;
      packet_done_pulse_i = 0;

      @ (posedge mpeg_clk_6MHz_i);
      
      #(4*CLK_HALF_PERIOD_NS);

      rst_n_i = 1;

      #(4*CLK_HALF_PERIOD_NS);

      packet_done_pulse_i = 1;

      #(2*CLK_HALF_PERIOD_NS);

      packet_done_pulse_i = 0;

      #(6*CLK_HALF_PERIOD_NS);

      @ (negedge mpeg_valid_out_o);

      #(6*CLK_HALF_PERIOD_NS);

      packet_done_pulse_i = 1;

      #(2*CLK_HALF_PERIOD_NS);

      packet_done_pulse_i = 0;

      #(6*CLK_HALF_PERIOD_NS);

      @ (negedge mpeg_valid_out_o);

      #(6*CLK_HALF_PERIOD_NS);
      
      $finish;
   end
   
endmodule // mpeg_controller_tb
