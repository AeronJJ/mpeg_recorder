`default_nettype none
module packet_buffer 
  #(
    parameter ADDR_WIDTH = 6,
    parameter MEM_WIDTH = 32,
    parameter PACKET_LENGTH = 188/4
    )
  (
   input wire                    rst_n,
  
   input wire                    w_clk,
   input wire                    w_en,
   input wire [ADDR_WIDTH - 1:0] w_addr,
   input wire [MEM_WIDTH - 1:0]  w_data,

   input wire                    r_clk,
   input wire                    r_en,
   input wire [ADDR_WIDTH - 1:0] r_addr,
   output wire [MEM_WIDTH - 1:0] r_data
   );

  ram_2_port_packet_buffer ram_2_port_packet_buffer_inst 
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
  
endmodule // packet_buffer
`default_nettype wire

