`default_nettype none
module packet_buffer 
  #(
    parameter ADDR_WIDTH = 8,
    parameter MEM_WIDTH = 32,
    parameter PACKET_LENGTH = 188
    )
   (
    input wire			  rst_n,
    
    input wire			  w_clk,
    input wire			  w_en,
    input wire [ADDR_WIDTH - 1:0] w_addr,
    input wire [MEM_WIDTH - 1:0]  w_data,

    input wire			  r_clk,
    input wire			  r_en,
    input wire [ADDR_WIDTH - 1:0] r_addr,
    output reg [MEM_WIDTH - 1:0]  r_data
    );

   reg [MEM_WIDTH - 1:0] buffer [PACKET_LENGTH - 1:0];

   always_ff @ (posedge w_clk or negedge rst_n) begin
      if (~rst_n) begin
	 // Eh
      end
      else if (w_en) begin
	 buffer[w_addr] <= w_data;
      end
   end

   always_ff @ (posedge r_clk or negedge rst_n) begin
      if (~rst_n) begin
	 r_data <= '0;
      end
      else if (r_en) begin
	 r_data <= buffer[r_addr];
      end
   end

endmodule // packet_buffer
`default_nettype wire
  
