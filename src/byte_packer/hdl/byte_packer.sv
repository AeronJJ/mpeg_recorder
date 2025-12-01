`default_nettype none
module byte_packer 
  #(
    parameter NUM_WRITE_BITS = 8,
    parameter NUM_WRITES = 4 // How many writes to pack into array
    )
   (
    input wire			      rst_n,
    
    input wire			      w_clk,
    input wire [NUM_WRITE_BITS - 1:0] w_data,

    input			      en,
    input			      sync, // Sync read clock to write clock

    output wire [NUM_READ_BITS - 1:0] data_packed
    );

   localparam NUM_READ_BITS = NUM_WRITES * NUM_WRITE_BITS;

   reg [NUM_WRITE_BITS - 1:0] data_arr [NUM_WRITES - 1:0];
   reg [$clog2(NUM_WRITES) - 1:0] data_arr_addr;

   genvar			  i;
   generate
      for (i=0; i < NUM_WRITES; i++) begin : pack_data
	 assign data_packed[(NUM_WRITES-1-i)*NUM_WRITE_BITS +: NUM_WRITE_BITS] = data_arr[i];
      end
   endgenerate
   
      
   always_ff @ (negedge w_clk or negedge rst_n) begin
      if (~rst_n) begin
	 for (int i = 0; i < NUM_WRITES; i++) begin
	    data_arr[i] <= '0;
	 end
      end
      else if (en) begin
	 data_arr[data_arr_addr] <= w_data;
      end
   end // always_ff @ (negedge w_clk or negedge rst_n) 
      
   always_ff @ (posedge w_clk or negedge rst_n) begin
      if (~rst_n) begin
	 data_arr_addr <= '0;
      end
      else if (en) begin
	 if (sync) begin
	    data_arr_addr <= '0;
	 end
	 else begin
	    data_arr_addr <= data_arr_addr + 1'b1;
	 end
      end
      else begin
	 data_arr_addr <= '0;
      end
   end // always_ff @ (posedge w_clk or negedge rst_n)

endmodule // byte_packer
`default_nettype wire
  
