`default_nettype none
module mpeg_controller 
  #(
    parameter PACKET_LENGTH = 188,
    parameter ADDR_WIDTH = $clog2(PACKET_LENGTH)
    )
   (
    input wire			   rst_n,
    input wire			   mpeg_clk_6MHz,
    
    input wire			   packet_done_pulse,
    
    output wire			   r_en,
    output wire [ADDR_WIDTH - 1:0] r_addr,
    output wire			   mpeg_sync_out,
    output reg			   mpeg_valid_out,
    output reg			   word_r_en
    );

   reg [ADDR_WIDTH - 1:0] r_addr_internal;
   assign r_addr = r_addr_internal;
   reg			  r_en_internal;
   assign r_en = r_en_internal;

   assign mpeg_sync_out = (r_addr_internal == ADDR_WIDTH'(1));
   assign mpeg_valid_out = (r_addr_internal != ADDR_WIDTH'(0));
      
   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin //
      if (~rst_n) begin
	 r_en_internal <= 1'b0;
      end
      else if (packet_done_pulse) begin
	 r_en_internal <= 1'b1;
      end
      else if (r_addr_internal == ADDR_WIDTH'(PACKET_LENGTH - 1)) begin
	 r_en_internal <= 1'b0;
      end
   end // always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n)
  
   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin //
      if (~rst_n) begin
	 r_addr_internal <= ADDR_WIDTH'(0);
      end
      else if (r_en_internal) begin
	 r_addr_internal <= r_addr_internal + ADDR_WIDTH'(1);
      end
      else begin
	 r_addr_internal <= ADDR_WIDTH'(0);
      end
   end // always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n)

   always_ff @ (negedge mpeg_clk_6MHz or negedge rst_n) begin //
      if (~rst_n) begin
	 word_r_en <= 1'b0;
      end
      else if (packet_done_pulse) begin
	 word_r_en <= 1'b1;
      end
      else if (r_en_internal) begin
	 word_r_en <= (r_addr_internal[1:0] == 2'b11);
      end
      else begin
	 word_r_en <= 1'b0;
      end
   end // always_ff @ (negedge w_clk or negedge rst_n)   

endmodule // mpeg_controller
`default_nettype wire
  
