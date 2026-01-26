`timescale 1ns/100ps
module msp2807_spi_tb;

   localparam CLK_FREQ = 100E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;
   
   localparam DATA_WIDTH = 8;

   /* verilator lint_off UNUSEDSIGNAL */
   
   reg	      rst_n_i;
   reg	      i_en_i;
   reg	      i_cdr_i;
   reg	      i_clk_i;
   reg [DATA_WIDTH - 1:0] i_data_i;
   wire			  o_busy_o;
   wire			  o_cs_o;
   wire			  o_dcrs_o;
   wire			  o_sdi_o;
   wire			  o_sck_o;
	

   msp2807_spi dut_msp2807_spi (
	.rst_n(rst_n_i),
	.i_en(i_en_i),
	.i_cdr(i_cdr_i),
	.i_clk(i_clk_i),
	.i_data(i_data_i),
	.o_busy(o_busy_o),
	.o_cs(o_cs_o),
	.o_dcrs(o_dcrs_o),
	.o_sdi(o_sdi_o),
	.o_sck(o_sck_o)
	);

   always #(CLK_HALF_PERIOD_NS) begin
      i_clk_i = ~i_clk_i;
   end

   localparam INIT_SEQ_LEN = 193;
   reg [8:0] INIT_SEQ [0:INIT_SEQ_LEN-1] = 
	    '{
	      // Sequence of Init messages, consists of both commands and parameters:
	      // Commands:  |  Paramaters....
	      {1'b0, 8'h28}, // Turn off Display
	      {1'b0, 8'hCF}, {1'b1, 8'h00}, {1'b1, 8'h83}, {1'b1, 8'h30}, // Power control B
	      {1'b0, 8'hED}, {1'b1, 8'h64}, {1'b1, 8'h03}, {1'b1, 8'h12}, {1'b1, 8'h81}, // Power on sequence control
	      {1'b0, 8'hE8}, {1'b1, 8'h85}, {1'b1, 8'h01}, {1'b1, 8'h79}, // Driver timing control A
	      {1'b0, 8'hCB}, {1'b1, 8'h39}, {1'b1, 8'h2C}, {1'b1, 8'h00}, {1'b1, 8'h34}, {1'b1, 8'h02}, // Power control A
	      {1'b0, 8'hF7}, {1'b1, 8'h20}, // Pump ratio control
	      {1'b0, 8'hEA}, {1'b1, 8'h00}, {1'b1, 8'h00}, // Driver timing control B
	      {1'b0, 8'hC0}, {1'b1, 8'h26}, // Power Control 1
	      {1'b0, 8'hC1}, {1'b1, 8'h11}, // Power Control 2
	      {1'b0, 8'hC5}, {1'b1, 8'h35}, {1'b1, 8'h3E}, // VCOM Control 1
	      {1'b0, 8'hC7}, {1'b1, 8'hBE}, // VCOM Control 2
	      {1'b0, 8'h3A}, {1'b1, 8'h55}, // COLMOD: Pixel Format Set (16 bit mode)
	      {1'b0, 8'hB1}, {1'b1, 8'h00}, {1'b1, 8'h1B}, // Frame Rate Control
	      {1'b0, 8'h26}, {1'b1, 8'h01}, // Gamma Set
	      {1'b0, 8'h51}, {1'b1, 8'hFF}, // Write Display Brightness
	      {1'b0, 8'hB7}, {1'b1, 8'h07}, // Entry Mode Set
	      {1'b0, 8'hB6}, {1'b1, 8'h0A}, {1'b1, 8'h82}, {1'b1, 8'h27}, {1'b1, 8'h00}, // Display Function Control
	      {1'b0, 8'h29}, // Display ON
	      //{1'b0, 8'h2C}  // Start Memory-Write
	      {1'b0, 8'h36}, {1'b1, 8'h28},
	      {1'b0, 8'h2A}, {1'b1, 8'h00}, {1'b1, 8'h00}, {1'b1, 8'h01}, {1'b1, 8'h3F},
	      {1'b0, 8'h2B}, {1'b1, 8'h00}, {1'b1, 8'h00}, {1'b1, 8'h00}, {1'b1, 8'hEF},
	    
	      {1'b0, 8'h2D}, {1'b1, 8'h0}, {1'b1, 8'h2}, {1'b1, 8'h4}, {1'b1, 8'h6}, {1'b1, 8'h8}, {1'b1, 8'hA}, {1'b1, 8'hC}, {1'b1, 8'hE}, {1'b1, 8'h10}, {1'b1, 8'h12}, {1'b1, 8'h14}, {1'b1, 8'h16}, {1'b1, 8'h18}, {1'b1, 8'h1A}, {1'b1, 8'h1C}, {1'b1, 8'h1E}, {1'b1, 8'h20}, {1'b1, 8'h22}, {1'b1, 8'h24}, {1'b1, 8'h26}, {1'b1, 8'h28}, {1'b1, 8'h2A}, {1'b1, 8'h2C}, {1'b1, 8'h2E}, {1'b1, 8'h30}, {1'b1, 8'h32}, {1'b1, 8'h34}, {1'b1, 8'h36}, {1'b1, 8'h38}, {1'b1, 8'h3A}, {1'b1, 8'h3C}, {1'b1, 8'h3E}, 
	      {1'b1, 8'h0}, {1'b1, 8'h1}, {1'b1, 8'h2}, {1'b1, 8'h3}, {1'b1, 8'h4}, {1'b1, 8'h5}, {1'b1, 8'h6}, {1'b1, 8'h7}, {1'b1, 8'h8}, {1'b1, 8'h9}, {1'b1, 8'hA}, {1'b1, 8'hB}, {1'b1, 8'hC}, {1'b1, 8'hD}, {1'b1, 8'hE}, {1'b1, 8'hF}, {1'b1, 8'h10}, {1'b1, 8'h11}, {1'b1, 8'h12}, {1'b1, 8'h13}, {1'b1, 8'h14}, {1'b1, 8'h15}, {1'b1, 8'h16}, {1'b1, 8'h17}, {1'b1, 8'h18}, {1'b1, 8'h19}, {1'b1, 8'h1A}, {1'b1, 8'h1B}, {1'b1, 8'h1C}, {1'b1, 8'h1D}, {1'b1, 8'h1E}, {1'b1, 8'h1F}, {1'b1, 8'h20}, {1'b1, 8'h21}, {1'b1, 8'h22}, {1'b1, 8'h23}, {1'b1, 8'h24}, {1'b1, 8'h25}, {1'b1, 8'h26}, {1'b1, 8'h27}, {1'b1, 8'h28}, {1'b1, 8'h29}, {1'b1, 8'h2A}, {1'b1, 8'h2B}, {1'b1, 8'h2C}, {1'b1, 8'h2D}, {1'b1, 8'h2E}, {1'b1, 8'h2F}, {1'b1, 8'h30}, {1'b1, 8'h31}, {1'b1, 8'h32}, {1'b1, 8'h33}, {1'b1, 8'h34}, {1'b1, 8'h35}, {1'b1, 8'h36}, {1'b1, 8'h37}, {1'b1, 8'h38}, {1'b1, 8'h39}, {1'b1, 8'h3A}, {1'b1, 8'h3B}, {1'b1, 8'h3C}, {1'b1, 8'h3D}, {1'b1, 8'h3E}, {1'b1, 8'h3F}, 
	      {1'b1, 8'h0}, {1'b1, 8'h2}, {1'b1, 8'h4}, {1'b1, 8'h6}, {1'b1, 8'h8}, {1'b1, 8'hA}, {1'b1, 8'hC}, {1'b1, 8'hE}, {1'b1, 8'h10}, {1'b1, 8'h12}, {1'b1, 8'h14}, {1'b1, 8'h16}, {1'b1, 8'h18}, {1'b1, 8'h1A}, {1'b1, 8'h1C}, {1'b1, 8'h1E}, {1'b1, 8'h20}, {1'b1, 8'h22}, {1'b1, 8'h24}, {1'b1, 8'h26}, {1'b1, 8'h28}, {1'b1, 8'h2A}, {1'b1, 8'h2C}, {1'b1, 8'h2E}, {1'b1, 8'h30}, {1'b1, 8'h32}, {1'b1, 8'h34}, {1'b1, 8'h36}, {1'b1, 8'h38}, {1'b1, 8'h3A}, {1'b1, 8'h3C}, {1'b1, 8'h3E},
	      {1'b0, 8'h2C}  // Start Memory-Write
	      };

   integer   i;
   
   // TODO: Implement verification by checking expected spi received signal against sent
   
   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();
      
      rst_n_i = 1'b0;
      i_en_i = 1'b0;
      i_cdr_i = 1'b0;
      i_clk_i = 1'b0;
      i_data_i = '0;
      
      #(10 * CLK_HALF_PERIOD_NS);
      @(posedge i_clk_i);
      
      rst_n_i = 1'b1;
      
      #(10 * CLK_HALF_PERIOD_NS);
      for (i = 0; i < INIT_SEQ_LEN; i = i + 1) begin
	 i_data_i = INIT_SEQ[i][7:0];
	 i_cdr_i = INIT_SEQ[i][8];
	 i_en_i = 1'b1;
	 #(2 * CLK_HALF_PERIOD_NS);
	 i_en_i = 1'b0;
	 @(negedge o_busy_o);
	 #(2 * CLK_HALF_PERIOD_NS);
      end
      
      
      $finish;
   end
   
endmodule // msp2807_spi_tb
