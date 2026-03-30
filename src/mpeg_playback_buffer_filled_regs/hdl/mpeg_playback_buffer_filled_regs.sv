`default_nettype none
module mpeg_playback_buffer_filled_regs
  (
   input wire        clk,
   input wire        rst,
   
   // Avalon-MM slave (LW bridge)
   input wire [1:0]  address,
   input wire        write,
   input wire [31:0] writedata,
   input wire        read,
   output reg [31:0] readdata,

   output reg        buffer0_filled,
   output reg        buffer1_filled
   );

  // internal register
  reg [31:0] control_reg;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      control_reg <= 1'b0;
      buffer0_filled <= 1'b0;
      buffer1_filled <= 1'b0;
    end 
    else if (write && (address == '0)) begin
      control_reg <= writedata;

      // generate pulses
      if (writedata[0]) begin
        buffer0_filled <= 1'b1;
      end

      if (writedata[1]) begin
        buffer1_filled <= 1'b1;
      end
    end
    else begin
      // default: pulses go low
      buffer0_filled <= 1'b0;
      buffer1_filled <= 1'b0;
    end
  end

  always_comb begin
    if (read && address == 0)
      readdata = control_reg;
    else
      readdata = 32'h0;
  end  
  
endmodule // mpeg_playback_buffer_filled_regs
`default_nettype wire

