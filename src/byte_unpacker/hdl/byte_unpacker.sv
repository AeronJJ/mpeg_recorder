`default_nettype none
module byte_unpacker 
  #(
    parameter NUM_READ_BITS = 8,
    parameter NUM_READS = 4
    )
   (
    input wire			      rst_n,

    input wire [NUM_WRITE_BITS - 1:0] w_data,

    input wire			      r_clk,
    output reg [NUM_READ_BITS - 1:0]  r_data,

    input wire			      en,
    input wire			      sync,

    output wire			      mpeg_sync			      
    );

   localparam NUM_WRITE_BITS = NUM_READ_BITS * NUM_READS;

   reg	      mpeg_sync_internal;
   // assign mpeg_sync_internal = sync & (r_addr == '0);
   assign mpeg_sync = mpeg_sync_internal;

   // reg sync_internal_tmp;
   // reg sync_internal;

   // always_ff @ (negedge r_clk or negedge rst_n) begin
   //    if (~rst_n) begin
   // 	 sync_internal_tmp <= 1'b0;
   // 	 sync_internal <= 1'b0;
   //    end
   //    else begin
   // 	 sync_internal_tmp <= sync;
   // 	 sync_internal <= sync_internal_tmp;
   //    end
   // end
   
   reg sync_track;
   
   always_ff @ (posedge r_clk or negedge rst_n) begin
      if (~rst_n) begin
	 mpeg_sync_internal <= 1'b0;
	 sync_track <= 1'b0;
      end
      else begin
	 if ((sync ^ mpeg_sync_internal) & ~sync_track) begin
	    mpeg_sync_internal <= (sync & (r_addr == '0));
	    sync_track <= 1'b1;
	 end
	 else begin
	    mpeg_sync_internal <= 1'b0;
	    if (~sync) begin
	       sync_track <= 1'b0;
	    end
	 end
      end
   end
      
   reg [$clog2(NUM_READS) - 1:0] r_addr;

   always_ff @ (negedge r_clk or negedge rst_n) begin
      if (~rst_n) begin
	 r_addr <= '0;
      end
      else if (en) begin
	 // if (mpeg_sync_internal) begin
	 if (sync & ~sync_track) begin
	    r_addr <= '0;
	 end
	 else begin
	    r_addr <= r_addr + 1'b1;
	 end
      end
      else begin
	 r_addr <= '0;
      end
   end

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
  
