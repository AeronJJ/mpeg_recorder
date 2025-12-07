`default_nettype none
module byte_unpacker 
  #(
    parameter NUM_READ_BITS = 8,
    parameter NUM_READS = 4,
    parameter ADDR_WIDTH = $clog2(NUM_READS)
    )
   (
    input wire			      rst_n,

    input wire [NUM_WRITE_BITS - 1:0] w_data,

    input wire			      r_clk,
    input wire [ADDR_WIDTH - 1:0]     r_addr,
    output reg [NUM_READ_BITS - 1:0]  r_data,

    input wire			      en		      
    );

   localparam NUM_WRITE_BITS = NUM_READ_BITS * NUM_READS;

   always_ff @ (posedge r_clk or negedge rst_n) begin
      if (~rst_n) begin
	 r_data <= '0;
      end
      else if (en) begin
	 for (int i = 0; i < NUM_READ_BITS; i++) begin
	    r_data[i] <= w_data[(NUM_READS - 1 - 32'(r_addr))*NUM_READ_BITS + i];
	 end
      end
      else begin
	 r_data <= '0;
      end
   end

endmodule // byte_unpacker
`default_nettype wire
  
