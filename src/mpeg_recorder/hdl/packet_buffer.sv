module packet_buffer 
  #(
    parameter PACKET_LENGTH_BYTES = 188,
    parameter WRITE_DATA_WIDTH = 8,
    parameter WRITE_ADDR_WIDTH = $clog2(PACKET_LENGTH_BYTES * 8 / WRITE_DATA_WIDTH),
    parameter READ_DATA_WIDTH  = 32,
    parameter READ_ADDR_WIDTH  = $clog2(PACKET_LENGTH_BYTES * 8 / READ_DATA_WIDTH)
    )
  (
   input  wire                          rst_n,

   // Write port
   input  wire                          w_clk,
   input  wire                          w_en,
   input  wire [WRITE_ADDR_WIDTH-1:0]   w_addr,
   input  wire [WRITE_DATA_WIDTH-1:0]   w_data,

   // Read port
   input  wire                          r_clk,
   input  wire                          r_en,
   input  wire [READ_ADDR_WIDTH-1:0]    r_addr,
   output reg  [READ_DATA_WIDTH-1:0]    r_data
   );
  
  // Model for Verilator of dual port ram //

  // Total memory in bits
  localparam TOTAL_BITS = PACKET_LENGTH_BYTES * 8;

  // Underlying storage as bytes
  reg [7:0] mem [0:PACKET_LENGTH_BYTES-1];

  // WRITE PORT (byte-oriented)
  always_ff @(posedge w_clk or negedge rst_n) begin
    if (!rst_n) begin
      integer i;
      for (i = 0; i < PACKET_LENGTH_BYTES; i++) begin
        mem[i] <= '0;
      end
    end else if (w_en) begin
      // WRITE_DATA_WIDTH assumed to be 8 here
      mem[w_addr] <= w_data;
    end
  end

  // READ PORT (word-oriented)
  integer j;
  always_ff @(posedge r_clk or negedge rst_n) begin
    if (!rst_n) begin
      r_data <= '0;
    end 
    else if (r_en) begin
      // Pack multiple bytes into READ_DATA_WIDTH word
      // Assumes READ_DATA_WIDTH is multiple of 8
      for (j = 0; j < READ_DATA_WIDTH/8; j++) begin
        r_data[j*8 +: 8] <= mem[r_addr*(READ_DATA_WIDTH/8) + j];
      end
    end
  end

endmodule
