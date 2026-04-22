`default_nettype none
module mpeg_irq_handler 
  (
   input wire        clk,
   input wire        rst,

   // Avalon-MM slave (LW bridge)
   input wire [7:0]  address,
   input wire        write,
   input wire [31:0] writedata,
   output reg        writeresponsevalid,
   output wire [1:0] writeresponse,
   input wire        read,
   output reg [31:0] readdata,
   output wire       readdatavalid,

   // IRQ reset pulse outputs
   output wire       irq_idle_reset,
   output wire       irq_record_reset,
   output wire       irq_playback_reset,
   output wire       irq_buf0_reset,
   output wire       irq_buf1_reset,
   output wire       irq_playback_buf0_reset,
   output wire       irq_playback_buf1_reset
   );

  assign writeresponse = 2'b00;

  // Registers for IRQ reset detection
  reg [31:0] irq_regs   [72:78];
  assign irq_idle_reset          = |irq_regs[72];
  assign irq_record_reset        = |irq_regs[73];
  assign irq_playback_reset      = |irq_regs[74];
  assign irq_buf0_reset          = |irq_regs[75];
  assign irq_buf1_reset          = |irq_regs[76];
  assign irq_playback_buf0_reset = |irq_regs[77];
  assign irq_playback_buf1_reset = |irq_regs[78];

  // Main logic
  integer    i;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      writeresponsevalid <= 0;

      // clear IRQ regs
      for (i = 72; i <= 78; i++) begin
        irq_regs[i] <= 32'h0;
      end

      // clear irq resets
      irq_idle_reset <= 0;
      irq_record_reset <= 0;
      irq_playback_reset <= 0;
      irq_buf0_reset <= 0;
      irq_buf1_reset <= 0;
      irq_playback_buf0_reset <= 0;
      irq_playback_buf1_reset <= 0;
    end 
    else begin
      writeresponsevalid <= write;

      // WRITE HANDLING
      // IRQ registers (72–78)
      if (write && address >= 8'd72 && address <= 8'd78) begin
        irq_regs[address] <= writedata;
      end
    end
  end

  // READ LOGIC
  always_comb begin
    if (address >= 8'd72 && address <= 8'd78) begin
      readdata = irq_regs[address];
    end
    else begin
      readdata = 32'h0;
    end
  end

  assign readdatavalid = read;
  
endmodule // mpeg_irq_handler
`default_nettype wire

