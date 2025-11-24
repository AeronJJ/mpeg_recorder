`timescale 1ns/100ps
module mpeg_recorder_tb;

   localparam CLK_FREQ = 40E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   localparam MPEG_CLK_FREQ = 6E6;
   localparam MPEG_CLK_HALF_PERIOD_NS = 5E8/MPEG_CLK_FREQ; 

   localparam MPEG_DATA_WIDTH = 8;
   localparam MPEG_MEM_LENGTH = 32;

   localparam int MEM_SIZE = 752;
   reg [7:0]	  mem [0:MEM_SIZE-1];
   
   initial begin
    $readmemh("4packets.hex", mem);
   end


      
   reg	      rst_n_i;
   reg	      mpeg_clk_6MHz_i;
   reg [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_i;
   reg			       mpeg_sync_i;
   reg			       mpeg_valid_i;
   reg			       sys_clk_40MHz_i;
   reg			       start_i;
   reg			       stop_i;
   
   wire [MPEG_MEM_LENGTH - 1:0]	r_data_o;
   

   mpeg_recorder dut_mpeg_recorder (
				    .rst_n(rst_n_i),
				    .mpeg_clk_6MHz(mpeg_clk_6MHz_i),
				    .mpeg_data_8(mpeg_data_8_i),
				    .mpeg_sync(mpeg_sync_i),
				    .mpeg_valid(mpeg_valid_i),
				    .sys_clk_40MHz(sys_clk_40MHz_i),
				    .start(start_i),
				    .stop(stop_i),
				    .r_data(r_data_o)
				    );

   always #(CLK_HALF_PERIOD_NS) begin
      sys_clk_40MHz_i = ~sys_clk_40MHz_i;
   end

   always #(MPEG_CLK_HALF_PERIOD_NS) begin
      mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
   end

   integer i;
   always_comb begin
      mpeg_sync_i = (i%188 == 0) ? 1'b1 : 1'b0;
   end
   
   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      rst_n_i = 1'b0;
      mpeg_clk_6MHz_i = 1'b0;
      sys_clk_40MHz_i = 1'b0;
      
      mpeg_data_8_i = '0;
      // mpeg_sync_i = 1'b0;
      mpeg_valid_i = 1'b1;
      
      start_i = 1'b0;

      #(6 * MPEG_CLK_HALF_PERIOD_NS);

      rst_n_i = 1'b1;

      #(6 * MPEG_CLK_HALF_PERIOD_NS);
      
      @ (posedge mpeg_clk_6MHz_i);
      
      start_i = 1'b1;
      for (i = 0; i < MEM_SIZE; i++) begin
	 $display("Byte %0d = 0x%02X", i, mem[i]);
	 mpeg_data_8_i = mem[i];
	 @ (posedge mpeg_clk_6MHz_i);
	 //#(2 * MPEG_CLK_HALF_PERIOD_NS);
	 // You can drive it into your DUT here:
         // dut.data_in <= mem[i];
         // #10;  // or your clock-based sequencing
      end
            
      $finish;
   end
   
endmodule // mpeg_recorder_tb
