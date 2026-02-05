`default_nettype none
module mpeg_recorder_avalon_mm_master_write 
  #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 30
    )
   (
    input wire                     clk,
    input wire                     rst_n,

    output wire [ADDR_WIDTH - 1:0] address,
    output wire [3:0]              burstcount,
    output wire [DATA_WIDTH - 1:0] writedata,
    output wire [3:0]              byteenable,
    output wire                    write,

    input wire                     waitrequest
    );

  assign address = address_internal;
  assign burstcount = 4'b0001;
  assign writedata = writedata_internal;
  assign byteenable = 4'b1111;
  assign write = write_internal;
  
  reg [ADDR_WIDTH - 1:0] address_internal;
  reg [DATA_WIDTH - 1:0] writedata_internal;
  reg                    write_internal;
  reg [31:0]             counter;

  always_ff @ (posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      address_internal <= '0;
      counter <= 32'd0;
      writedata_internal <= '0;
      write_internal <= 1'b0;
    end
    else if (~waitrequest) begin
      write_internal <= 1'b1;
      writedata_internal <= counter;
      address_internal <= address_internal + 1;
      counter <= counter + 1;
    end
    else begin
      write_internal <= 1'b0;
    end
  end

endmodule // mpeg_recorder_avalon_mm_master_write
`default_nettype wire
  
