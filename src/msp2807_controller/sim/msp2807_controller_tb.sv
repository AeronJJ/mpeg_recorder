`timescale 1ns/100ps
module msp2807_controller_tb;

   localparam CLK_FREQ = 100E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   /* verilator lint_off UNUSEDSIGNAL */
   
   reg	      rst_n_i;
   reg	      sys_clk_100MHz_i;
   reg [15:0] pixel_data_i;
   reg	      pixel_available_i;
   wire	      pixel_done_o;
   wire	      o_cs_o;
   wire	      o_dcrs_o;
   wire	      o_sdi_o;
   wire	      o_sck_o;
   wire	      o_lcdrst_o;
   reg	      rst_coord_i;
   wire [8:0] x_o;
   wire [7:0] y_o;
   wire [16:0] bufferIndex_o;
   

   msp2807_controller dut_msp2807_controller 
     (
      .rst_n(rst_n_i),
      .sys_clk_100MHz(sys_clk_100MHz_i),
      .pixel_data(pixel_data_i),
      .pixel_available(pixel_available_i),
      .pixel_done(pixel_done_o),
      .o_cs(o_cs_o),
      .o_dcrs(o_dcrs_o),
      .o_sdi(o_sdi_o),
      .o_sck(o_sck_o),
      .o_lcdrst(o_lcdrst_o),
      .rst_coord(rst_coord_i),
      .x(x_o),
      .y(y_o),
      .bufferIndex(bufferIndex_o)
      );

   always #(CLK_HALF_PERIOD_NS) begin
      sys_clk_100MHz_i = ~sys_clk_100MHz_i;
   end

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      rst_n_i = 1'b0;
      sys_clk_100MHz_i = 1'b0;
      pixel_data_i = 16'hAFF5; // 10101 111111 10101 AF F5
      pixel_available_i = 1'b0;
      rst_coord_i = 1'b0;

      #(10*CLK_HALF_PERIOD_NS);

      rst_n_i = 1'b1;
      
      #(10*CLK_HALF_PERIOD_NS);
      pixel_available_i = 1'b1;

      #(10*CLK_HALF_PERIOD_NS);
      @(bufferIndex_o == 1);
      @(bufferIndex_o == '0);

      @(bufferIndex_o == 100);
      rst_coord_i = 1'b1;
      @(bufferIndex_o == '0);
      #(1000*CLK_HALF_PERIOD_NS);
      rst_coord_i = 1'b0;
      @(bufferIndex_o == 1);
      @(bufferIndex_o == '0);
      
      
      
      $finish;
   end
   
endmodule // msp2807_controller_tb
