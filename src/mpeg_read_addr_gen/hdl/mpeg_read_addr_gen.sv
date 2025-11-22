`default_nettype none
module mpeg_read_addr_gen 
  #(
    parameter MPEG_ADDR_WIDTH = 8,
    parameter MPEG_PACKET_LENGTH = 188
    )
   (
    input wire			       rst_n,
    input wire			       r_clk,
    input wire			       en,
    input wire			       start, // Pulse to start once or leave high to run continuously

    output reg [MPEG_ADDR_WIDTH - 1:0] r_addr,
    output wire			       r_end
    );

   assign r_end = (r_addr == MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH - 1));
   
   always_ff @ (posedge r_clk or negedge rst_n) begin
      if (~rst_n) begin
	 r_addr <= MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH - 1);
      end
      else if (en) begin
	 if (r_addr != MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH - 1)) begin
	    r_addr <= r_addr + 1'b1;	 
	 end
	 else if (start) begin
	    r_addr <= '0;
	 end
      end
      else begin
	 r_addr <= MPEG_ADDR_WIDTH'(MPEG_PACKET_LENGTH - 1);
      end
   end

endmodule // mpeg_read_addr_gen
`default_nettype wire
  
