`default_nettype none
module msp2807_spi 
  #(
    parameter DATA_WIDTH = 8
    )
   (
    input wire			  rst_n,
    
    input wire			  i_en,
    input wire			  i_cdr,  // command/data 
    input wire			  i_clk,  // Input clock, ~100 MHz
    input wire [DATA_WIDTH - 1:0] i_data, // 8 bit message input
	  
    output reg			  o_busy,
	  
    output reg			  o_cs,
    output reg			  o_dcrs,
    output reg			  o_sdi,  // Data output pin
    output wire			  o_sck	  // SPI clock ~50% of input clock so ~50 MHz    
    );

   localparam DATA_COUNTER_WIDTH = $clog2(DATA_WIDTH);
   
   reg [DATA_WIDTH - 1:0] internal_data;
   /* verilator lint_off ASCRANGE */
   reg [0:DATA_COUNTER_WIDTH - 1] data_counter =  DATA_COUNTER_WIDTH'(0);
   /* verilator lint_on ASCRANGE */
   reg				   internal_sck;

   /* verilator lint_off ASCRANGE */
   wire [0:DATA_WIDTH - 1]	   reversed_data;
   /* verilator lint_on ASCRANGE */

   assign reversed_data[0:DATA_WIDTH - 1] = internal_data[DATA_WIDTH - 1:0];
   assign o_sck = internal_sck & ~o_cs;

   always_ff @ (posedge i_clk or negedge rst_n) begin
      if (~rst_n) begin
	 internal_data <= '0;
	 internal_sck <= 1'b1;
	 data_counter <= '0;
	 o_busy <= 1'b0;
	 o_dcrs <= 1'b0;
	 o_sdi <= 1'b0;
	 o_cs <= 1'b0;	 
      end
      else begin
	 if (i_en) begin // Load next byte in
	    internal_data <= i_data;
	    o_busy <= 1'b1;
	 end      
	 if (o_busy) begin
	    internal_sck <= !internal_sck; // Drive SPI clock
	    if (internal_sck) begin // Operate when clock is high
	       o_dcrs <= i_cdr; // Set command/data pin
	       o_sdi <= reversed_data[data_counter]; // Send next data bit
	       o_cs <= 1'b0; // Set chip select low
	       data_counter <= data_counter + 1'b1; // Increment data counter
	       o_busy <= ~&data_counter; // Busy flag is low if data counter bits are all ones
	    end
	 end
	 else begin
	    internal_sck <= 1'b1;
	    if (internal_sck) begin
	       o_cs <= 1'b1;
	    end
	 end // else: !if(o_busy)
      end // else: !if(~rst_n)
   end

endmodule // msp2807_spi
`default_nettype wire
  
