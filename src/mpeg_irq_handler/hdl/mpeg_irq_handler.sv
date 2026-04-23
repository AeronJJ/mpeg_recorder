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
   output reg        readdatavalid,

   // IRQ reset pulse outputs
   output wire       idle_irq_received,
   output wire       record_irq_received,
   output wire       playback_irq_received,
   output wire       buffer0_done_irq_received,
   output wire       buffer1_done_irq_received,
   output wire       buffer0_fill_request_irq_received,
   output wire       buffer1_fill_request_irq_received,

   output wire [6:0] led_test_signal
   );

  assign led_test_signal = {
                            idle_irq_received,
                            record_irq_received,
                            playback_irq_received,
                            buffer0_done_irq_received,
                            buffer1_done_irq_received,
                            buffer0_fill_request_irq_received,
                            buffer1_fill_request_irq_received
                            };
  
  assign writeresponse = 2'b00;

  // Registers for IRQ reset detection
  reg [31:0] irq_regs   [72:78];
  assign idle_irq_received                 = |irq_regs[72];
  assign record_irq_received               = |irq_regs[73];
  assign playback_irq_received             = |irq_regs[74];
  assign buffer0_done_irq_received         = |irq_regs[75];
  assign buffer1_done_irq_received         = |irq_regs[76];
  assign buffer0_fill_request_irq_received = |irq_regs[77];
  assign buffer1_fill_request_irq_received = |irq_regs[78];

  // Main logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      writeresponsevalid <= 0;

      // clear IRQ regs
      irq_regs[72] <= 32'h0;
      irq_regs[73] <= 32'h0;
      irq_regs[74] <= 32'h0;
      irq_regs[75] <= 32'h0;
      irq_regs[76] <= 32'h0;
      irq_regs[77] <= 32'h0;
      irq_regs[78] <= 32'h0;
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
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      readdata <= '0;
      readdatavalid <= 1'b0;
    end
    else if (read) begin
      if (address >= 8'd72 && address <= 8'd78) begin
        readdata <= irq_regs[address];
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
    
endmodule // mpeg_irq_handler
`default_nettype wire

