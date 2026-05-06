`default_nettype none
module mpeg_playback_buffer_filled_regs
  (
   input wire        clk,
   input wire        rst,

   // Avalon-MM slave (LW bridge)
   input wire [1:0]  address,
   input wire        write,
   input wire [31:0] writedata,
   output reg        writeresponsevalid,
   output wire [1:0] writeresponse,
   input wire        read,
   output reg [31:0] readdata,
   output reg        readdatavalid,

   output reg        buffer0_filled,
   output reg        buffer1_filled
   );

  assign writeresponse = 2'b00;

  reg write_accepted;
  reg [31:0] control_reg;

  // WRITE LOGIC
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      control_reg        <= 32'h0;
      buffer0_filled     <= 1'b0;
      buffer1_filled     <= 1'b0;
      write_accepted     <= 1'b0;
      writeresponsevalid <= 1'b0;
    end 
    else begin
      // default: pulses low
      buffer0_filled <= 1'b0;
      buffer1_filled <= 1'b0;

      // detect write acceptance
      write_accepted <= write && (address == 2'd0);

      // generate write response one cycle later
      writeresponsevalid <= write_accepted;

      // handle write
      if (write && (address == 2'd0)) begin
        control_reg <= writedata;

        if (writedata[0])
          buffer0_filled <= 1'b1;

        if (writedata[1])
          buffer1_filled <= 1'b1;
      end
    end
  end

  // READ LOGIC
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      readdata <= '0;
      readdatavalid <= 1'b0;
    end
    else if (read) begin
      if (address == 2'd0) begin
        readdata <= control_reg;
      end
      else begin
        readdata <= '0;
      end
      readdatavalid <= 1'b1;
    end
    else begin
      readdatavalid <= 1'b0;
    end
  end // always_ff @ (posedge clk or posedge rst)

endmodule
`default_nettype wire
