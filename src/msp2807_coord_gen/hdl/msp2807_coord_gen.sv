`default_nettype none
module msp2807_coord_gen 
  #(
    parameter X_COUNT = 320, 
    parameter Y_COUNT = 240, 
    parameter X_WIDTH = 9, 
    parameter Y_WIDTH = 8    
    )
   (
    input wire			  rst_n,
    input wire			  clk,
    input wire			  en,
    input wire			  increment,
    input wire			  clear,
   
    output reg [X_WIDTH - 1:0]	  x,
    output reg [Y_WIDTH - 1:0]	  y,
    output reg [INDEX_SIZE - 1:0] index
    );

   localparam INDEX_SIZE = X_WIDTH + Y_WIDTH;
   localparam LCD_SIZE = INDEX_SIZE'(X_COUNT * Y_COUNT);

   always_ff @ (posedge clk or negedge rst_n) begin
      if (~rst_n) begin
	 x <= '0;
	 y <= '0;
	 index <= '0;
      end
      else if (clear) begin
	 x <= '0;
	 y <= '0;
	 index <= '0;
      end
      else if (en) begin
	 if (index == LCD_SIZE) begin
	    x <= '0;
	    y <= '0;
	    index <= '0;
	 end
	 else if (increment) begin
	    index <= index + 1'b1;
	    if (x == X_COUNT - 1'b1) begin
	       x <= '0;
	       y <= y + 1'b1;
	    end
	    else begin
	       x <= x + 1'b1;
	    end
	 end
      end
   end
   

endmodule // msp2807_coord_gen
`default_nettype wire

