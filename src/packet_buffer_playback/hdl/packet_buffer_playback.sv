`default_nettype none
module packet_buffer_playback 
  #(
    parameter PACKET_LENGTH_BYTES = 188,
    parameter WRITE_DATA_WIDTH = 32,
    parameter WRITE_ADDR_WIDTH = $clog2(PACKET_LENGTH_BYTES * 8 / WRITE_DATA_WIDTH),
    parameter READ_DATA_WIDTH = 8,
    parameter READ_ADDR_WIDTH = $clog2(PACKET_LENGTH_BYTES * 8 / READ_DATA_WIDTH)   
    )
  (
   input wire                          rst_n,
  
   input wire                          w_clk,
   input wire                          w_en,
   input wire [WRITE_ADDR_WIDTH - 1:0] w_addr,
   input wire [WRITE_DATA_WIDTH - 1:0] w_data,

   input wire                          r_clk,
   input wire                          r_en,
   input wire [READ_ADDR_WIDTH - 1:0]  r_addr,
   output wire [READ_DATA_WIDTH - 1:0] r_data
   );

  ram_2_port_packet_buffer_out ram_2_port_packet_buffer_out_inst 
    (
     .data      (w_data),
     .rdaddress (r_addr),
     .rdclock   (r_clk),
     .rden      (r_en),
     .wraddress (w_addr),
     .wrclock   (w_clk),
     .wren      (w_en),
     .q         (r_data)
     );
  
endmodule // packet_buffer_playback
`default_nettype wire
  
