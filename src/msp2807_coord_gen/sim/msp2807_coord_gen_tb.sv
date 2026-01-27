`timescale 1ns/100ps
module msp2807_coord_gen_tb;

   localparam CLK_FREQ = 100E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   parameter  X_WIDTH = 9;
   parameter  Y_WIDTH = 8;
   localparam INDEX_SIZE = X_WIDTH + Y_WIDTH;   
   
   reg rst_n_i;
   reg clk_i;
   reg en_i;
   reg increment_i;
   reg clear_i;
   wire [X_WIDTH - 1:0]	x_o;
   wire [Y_WIDTH - 1:0]	y_o;
   wire [INDEX_SIZE - 1:0] index_o;
	

   msp2807_coord_gen dut_msp2807_coord_gen (
	.rst_n(rst_n_i),
	.clk(clk_i),
	.en(en_i),
	.increment(increment_i),
	.clear(clear_i),
	.x(x_o),
	.y(y_o),
	.index(index_o)
	);

   always #(CLK_HALF_PERIOD_NS) begin
      clk_i = ~clk_i;
   end

   always #(2*CLK_HALF_PERIOD_NS) begin
      increment_i = ~increment_i;
   end

   
   reg [X_WIDTH - 1:0]	prev_x;
   reg [Y_WIDTH - 1:0]	prev_y;
   reg [INDEX_SIZE - 1:0] prev_index;

   always_ff @ (posedge clk_i) begin
      prev_x <= x_o;
      prev_y <= y_o;
      prev_index <= index_o;
   end
   

   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      rst_n_i = 1'b0;
      clk_i = 1'b0;
      en_i = 1'b0;
      increment_i = 1'b0;
      clear_i = 1'b0;

      #(10*CLK_HALF_PERIOD_NS);

      rst_n_i = 1'b1;
      
      #(10*CLK_HALF_PERIOD_NS);

      // Enable
      en_i = 1'b1;

      #(10*CLK_HALF_PERIOD_NS);

      @(x_o == '0);
      if (prev_x != 319) begin
	 $display("x rolled to zero at value other than 319: %d", prev_x);
      end

      @(index_o == '0);
      if (prev_index != 76799) begin
	 $display("Index rolled to zero at value other than 76799: %d", prev_index);
      end

      
      if (prev_y != 239) begin
	 $display("y rolled to zero at value other than 239: %d", prev_y);
      end
      
      #(10*CLK_HALF_PERIOD_NS);

      @(index_o == 1000);

      clear_i = 1'b1;
      
      #(10*CLK_HALF_PERIOD_NS);
      if (index_o == '0) begin
	 $display("Successfully cleared");
      end
      else begin
	 $display("Index not cleared: %d", index_o);
	 $display("x: %d", x_o);
	 $display("y: %d", y_o);
      end
      
      $finish;
   end
   
endmodule // msp2807_coord_gen_tb
